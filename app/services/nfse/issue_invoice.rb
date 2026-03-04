# frozen_string_literal: true

module Nfse
  class IssueInvoice
    def self.call(invoice, **deps)
      new(invoice, **deps).call
    end

    def initialize(invoice,
                   validator: XmlValidator.new,
                   signer: XmlSigner.new,
                   compressor: XmlCompressor.new,
                   client: Client.new)
      @invoice    = invoice
      @validator  = validator
      @signer     = signer
      @compressor = compressor
      @client     = client
    end

    def call
      dps_xml  = load_dps_xml
      signed   = sign_and_compress(dps_xml)
      payload  = build_payload(signed[:compressed], dps_xml)
      response = send_request(payload)
      process_response(response, signed[:xml])
    rescue StandardError => e
      Result.failure(e.message)
    end

    private

    def load_dps_xml
      @invoice.dps_xml.presence || raise("missing dps_xml on invoice")
    end

    def sign_and_compress(dps_xml)
      @validator.validate_dps!(dps_xml)
      signed_xml = @signer.sign(dps_xml)
      { xml: signed_xml, compressed: @compressor.compress(signed_xml) }
    end

    def build_payload(compressed_xml, raw_dps_xml)
      doc  = parse_dps(raw_dps_xml)
      cnpj = fetch_node!(doc, "//infDPS/prest/CNPJ")
      cloc = fetch_node!(doc, "//infDPS/cLocEmi")
      { xml: compressed_xml, cnpj: cnpj, municipioPrestador: cloc }
    end

    def parse_dps(xml_string)
      Nokogiri::XML(xml_string).tap(&:remove_namespaces!)
    end

    def fetch_node!(doc, xpath)
      doc.at_xpath(xpath)&.text || raise(Errors::ValidationError, "missing #{xpath} in DPS")
    end

    def send_request(payload)
      response = @client.post(payload)
      raise Errors::GatewayError, "HTTP #{response.code}" unless response.success?
      JSON.parse(response.body)
    end

    def process_response(response, signed_xml)
      access_key = response["chaveAcesso"] or raise("missing chaveAcesso in response")
      nfse_xml   = @compressor.decompress(response["xml"])
      @validator.validate_nfse!(nfse_xml)
      persist_result(access_key, nfse_xml, response["xml"], signed_xml)
      Result.success(@invoice)
    end

    def persist_result(access_key, nfse_xml, compressed_nfse_xml, signed_xml)
      @invoice.update!(
        access_key:          access_key,
        nfse_xml:            nfse_xml,
        compressed_nfse_xml: compressed_nfse_xml,
        signed_dps_xml:      signed_xml,
        consultation_url:    "https://www.nfse.gov.br/consulta/#{access_key}",
        status:              :issued
      )
    end
  end
end
