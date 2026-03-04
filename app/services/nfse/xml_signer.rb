# frozen_string_literal: true

module Nfse
  class XmlSigner
    def initialize(cert_path: ENV.fetch("NFSE_CERT_PATH"),
                   cert_password: ENV.fetch("NFSE_CERT_PASSWORD"))
      @cert_path     = cert_path
      @cert_password = cert_password
    end

    def sign(xml_string)
      doc    = Nokogiri::XML(xml_string)
      pkcs12 = load_certificate
      attach_signature(doc, pkcs12)
      doc.to_xml
    end

    private

    NFSE_NS = "http://www.sped.fazenda.gov.br/nfse"

    def attach_signature(doc, pkcs12)
      inf_dps   = fetch_inf_dps!(doc)
      ref_id    = fetch_ref_id!(inf_dps)
      digest    = compute_digest(inf_dps)
      sig_info  = build_signed_info_node(ref_id, digest)
      sig_value = sign_signed_info(sig_info, pkcs12.key)
      doc.root.add_child(wrap_signature(sig_info, sig_value, pkcs12.certificate))
    end

    def fetch_inf_dps!(doc)
      doc.at_xpath("//nfse:infDPS", "nfse" => NFSE_NS) ||
        raise(Errors::ValidationError, "missing infDPS element in DPS XML")
    end

    def fetch_ref_id!(inf_dps)
      inf_dps["Id"].presence ||
        raise(Errors::ValidationError, "missing Id attribute on infDPS")
    end

    def load_certificate
      OpenSSL::PKCS12.new(File.read(@cert_path), @cert_password)
    end

    def compute_digest(node)
      canon = node.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
      Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(canon))
    end

    def build_signed_info_node(ref_id, digest)
      Nokogiri::XML::Builder.new do |xml|
        xml.SignedInfo(xmlns: "http://www.w3.org/2000/09/xmldsig#") do
          xml.CanonicalizationMethod(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#")
          xml.SignatureMethod(Algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256")
          build_reference(xml, ref_id, digest)
        end
      end.doc.root
    end

    def sign_signed_info(sig_info_node, key)
      canon = sig_info_node.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
      Base64.strict_encode64(key.sign(OpenSSL::Digest::SHA256.new, canon))
    end

    def wrap_signature(sig_info, sig_value, cert)
      Nokogiri::XML::Builder.new do |xml|
        xml.Signature(xmlns: "http://www.w3.org/2000/09/xmldsig#") do
          xml.parent << sig_info.dup
          xml.SignatureValue sig_value
          build_key_info(xml, cert)
        end
      end.doc.root
    end

    def build_reference(xml, ref_id, digest)
      xml.Reference(URI: "##{ref_id}") do
        xml.DigestMethod(Algorithm: "http://www.w3.org/2001/04/xmlenc#sha256")
        xml.DigestValue(digest)
      end
    end

    def build_key_info(xml, cert)
      xml.KeyInfo do
        xml.X509Data { xml.X509Certificate(Base64.strict_encode64(cert.to_der)) }
      end
    end
  end
end
