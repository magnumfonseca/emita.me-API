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

    def attach_signature(doc, pkcs12)
      digest    = compute_digest(doc.root)
      sig_value = sign_digest(digest, pkcs12.key)
      insert_signature(doc, digest, sig_value, pkcs12.certificate)
    end

    def load_certificate
      OpenSSL::PKCS12.new(File.read(@cert_path), @cert_password)
    end

    def compute_digest(node)
      canon = node.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
      Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(canon))
    end

    def sign_digest(digest, key)
      raw = Base64.strict_decode64(digest)
      Base64.strict_encode64(key.sign(OpenSSL::Digest::SHA256.new, raw))
    end

    def insert_signature(doc, digest, sig_value, cert)
      ref_id   = doc.root["Id"] || "DPS"
      sig_node = build_signature_node(ref_id: ref_id, digest: digest, sig_value: sig_value, cert: cert)
      doc.root.add_child(sig_node)
    end

    def build_signature_node(ref_id:, digest:, sig_value:, cert:)
      Nokogiri::XML::Builder.new do |xml|
        xml.Signature(xmlns: "http://www.w3.org/2000/09/xmldsig#") do
          build_signed_info(xml, ref_id, digest)
          xml.SignatureValue(sig_value)
          build_key_info(xml, cert)
        end
      end.doc.root
    end

    def build_signed_info(xml, ref_id, digest)
      xml.SignedInfo do
        xml.CanonicalizationMethod(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#")
        xml.SignatureMethod(Algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256")
        build_reference(xml, ref_id, digest)
      end
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
