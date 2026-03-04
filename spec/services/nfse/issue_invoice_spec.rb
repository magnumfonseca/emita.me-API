# frozen_string_literal: true

require "rails_helper"

DPS_XML = File.read(Rails.root.join("spec/fixtures/xml/dps_example.xml"))

RSpec.describe Nfse::IssueInvoice do
  let(:dps_xml)   { DPS_XML }
  let(:invoice)   { create(:invoice, dps_xml: dps_xml) }

  let(:validator)  { instance_double(Nfse::XmlValidator, validate_dps!: nil, validate_nfse!: nil) }
  let(:signer)     { instance_double(Nfse::XmlSigner, sign: dps_xml) }
  let(:compressor) do
    instance_double(Nfse::XmlCompressor,
      compress:   "FAKE_BASE64_XML",
      decompress: "<NFSe>fake</NFSe>"
    )
  end

  subject(:result) do
    VCR.use_cassette("govbr/nfse_issue") do
      described_class.call(invoice, validator:, signer:, compressor:)
    end
  end

  it "returns a successful result" do
    expect(result).to be_success
    expect(result.data).to eq(invoice)
  end

  it "updates the invoice with NFS-e data" do
    result
    expect(invoice.reload).to have_attributes(
      access_key:       "NFS-e-3550308-2026-00000000000000000000000000000000000000000000",
      status:           "issued",
      consultation_url: include("NFS-e-3550308-2026"),
      signed_dps_xml:   be_present
    )
  end

  context "when chaveAcesso is missing from response" do
    it "returns failure" do
      http_response = instance_double(HTTParty::Response, success?: true, body: "{}")
      client = instance_double(Nfse::Client, post: http_response)
      result = described_class.call(invoice, validator:, signer:, compressor:, client:)
      expect(result).to be_failure
    end
  end

  context "when HTTP request fails" do
    it "returns failure" do
      http_response = instance_double(HTTParty::Response, success?: false, code: 500)
      client = instance_double(Nfse::Client, post: http_response)
      result = described_class.call(invoice, validator:, signer:, compressor:, client:)
      expect(result).to be_failure
    end
  end
end
