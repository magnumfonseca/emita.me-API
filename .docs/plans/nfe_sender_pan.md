# NFS-e National Issuance Service — Execution Plan

## Context

The application needs to issue NFS-e (Nota Fiscal de Serviços Eletrônica Nacional) invoices via the
official Brazilian government API (`api.nfse.gov.br`). The service must:

1. Validate a DPS XML against official XSD schemas
2. Sign it using XMLDSig (RSA-SHA256)
3. GZip + Base64 compress the signed XML
4. POST it to the API with mTLS
5. Parse and store the returned NFS-e data on the `Invoice` record

This runs in test mode today (fake cert, fixture XML, VCR cassette) until real credentials arrive.

---

## Key Constraints

- **Reuse existing `Result` class** (`app/lib/result.rb`) — no new result object needed
- **Dependency injection** for `signer`, `compressor`, `validator`, `client` to enable VCR compatibility
- **VCR cassette body** is `FAKE_BASE64_XML` → compressor must be stubbed in specs to return that value
- **`company_cnpj` and `city_code`** are not Invoice model fields → parse from DPS XML (`<Prestador><CNPJ>` and `<CodigoMunicipio>`)
- **New gems required**: `nokogiri` (XML/XSD/C14N) — use existing `httparty` for HTTP/mTLS (no faraday needed)
- **All file paths via ENV vars** — schemas path, cert path, cert password, and API URL must come from ENV so no code changes are needed for production
- **XSD schemas path** → `ENV["NFSE_SCHEMAS_PATH"]` (set to `.docs/references/schemas` in test env)
- **Cert path/password** → `ENV["NFSE_CERT_PATH"]` / `ENV["NFSE_CERT_PASSWORD"]`
- **API URL** → `ENV["NFSE_API_URL"]`

---

## Files to Create / Modify

| Action   | File                                              | Purpose                                      |
|----------|---------------------------------------------------|----------------------------------------------|
| Modify   | `Gemfile`                                         | Add `nokogiri` only (httparty already present) |
| Modify   | `.env`                                            | Add NFSE_* ENV vars                          |
| Create   | `app/lib/errors/validation_error.rb`              | New error class for XSD failures             |
| Create   | `app/services/nfse/xml_validator.rb`              | Validate XML against XSD schemas             |
| Create   | `app/services/nfse/xml_signer.rb`                 | XMLDSig RSA-SHA256 signing                   |
| Create   | `app/services/nfse/xml_compressor.rb`             | GZip + Base64 encode/decode                  |
| Create   | `app/services/nfse/client.rb`                     | HTTParty with mTLS client certificate        |
| Create   | `app/services/nfse/issue_invoice.rb`              | Main orchestrator service                    |
| Create   | `spec/services/nfse/issue_invoice_spec.rb`        | Integration spec using VCR cassette          |

**Existing assets to reuse:**
- `app/lib/result.rb` — `Result.success(data)` / `Result.failure(error)`
- `spec/vcr_cassettes/govbr/nfse_issue.yml` — pre-recorded API response
- `spec/support/certs/test_cert.pfx` — fake PKCS#12 cert (password: `"123456"`)
- `spec/fixtures/xml/dps_example.xml` — fake DPS XML input
- `.docs/references/schemas/*.xsd` — XSD schemas for validation

---

## Step-by-Step Implementation

### Step 0 — Environment Variables

All file paths and external coordinates must be set via ENV, so no code changes are needed between environments.

Add to `.env.test` (test values):
```
NFSE_SCHEMAS_PATH=/absolute/path/to/.docs/references/schemas
NFSE_CERT_PATH=/absolute/path/to/spec/support/certs/test_cert.pfx
NFSE_CERT_PASSWORD=123456
NFSE_API_URL=https://api.nfse.gov.br/nfse
```

Production `.env` (or secrets manager) supplies real paths/credentials — zero code changes required.
Update `.env.example`.
---

### Step 1 — Gemfile

Add to `Gemfile` (main group, alongside `httparty`):
```ruby
gem "nokogiri"
```

Run `bundle install`. `faraday` is not needed — `httparty` already supports mTLS client certificates.

---

### Step 2 — `Errors::ValidationError`

```ruby
# app/lib/errors/validation_error.rb
module Errors
  class ValidationError < StandardError; end
end
```

---

### Step 3 — `Nfse::XmlValidator`

```ruby
# app/services/nfse/xml_validator.rb
module Nfse
  class XmlValidator
    SCHEMAS_PATH = Pathname.new(ENV.fetch("NFSE_SCHEMAS_PATH"))

    def validate_dps!(xml_string)
      validate!(xml_string, schema_for("DPS_v1.01.xsd"))
    end

    def validate_nfse!(xml_string)
      validate!(xml_string, schema_for("NFSe_v1.01.xsd"))
    end

    private

    def validate!(xml_string, schema)
      doc    = Nokogiri::XML(xml_string)
      errors = schema.validate(doc)
      raise Errors::ValidationError, errors.map(&:message).join(", ") unless errors.empty?
    end

    def schema_for(filename)
      Nokogiri::XML::Schema(File.read(SCHEMAS_PATH.join(filename)))
    end
  end
end
```

---

### Step 4 — `Nfse::XmlSigner`

Implements XMLDSig as required by the manual:
- Canonicalize XML (C14N exclusive)
- SHA256 digest of the root element
- RSA-SHA256 signature using private key from PKCS#12 cert
- Insert `<Signature>` block with `<KeyInfo>` containing the certificate

```ruby
# app/services/nfse/xml_signer.rb
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
```

---

### Step 5 — `Nfse::XmlCompressor`

Uses Ruby stdlib only (`Zlib`, `Base64`) — no extra gem:

```ruby
# app/services/nfse/xml_compressor.rb
module Nfse
  class XmlCompressor
    def compress(xml_string)
      Base64.strict_encode64(gzip(xml_string))
    end

    def decompress(base64_string)
      gzipped = Base64.strict_decode64(base64_string)
      Zlib::GzipReader.new(StringIO.new(gzipped)).read
    end

    private

    def gzip(data)
      output = StringIO.new
      gz     = Zlib::GzipWriter.new(output)
      gz.write(data)
      gz.close
      output.string
    end
  end
end
```

---

### Step 6 — `Nfse::Client`

Uses `HTTParty` (already in Gemfile) with mTLS via the `:p12` option:

```ruby
# app/services/nfse/client.rb
module Nfse
  class Client
    include HTTParty

    API_URL = ENV.fetch("NFSE_API_URL")

    def initialize(cert_path: ENV.fetch("NFSE_CERT_PATH"),
                   cert_password: ENV.fetch("NFSE_CERT_PASSWORD"))
      @cert_path     = cert_path
      @cert_password = cert_password
    end

    def post(payload)
      self.class.post(
        API_URL,
        body:         payload.to_json,
        headers:      { "Content-Type" => "application/json" },
        p12:          File.read(@cert_path),
        p12_password: @cert_password
      )
    end
  end
end
```

---

### Step 7 — `Nfse::IssueInvoice` (main orchestrator)

```ruby
# app/services/nfse/issue_invoice.rb
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
    rescue => e
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
      doc = Nokogiri::XML(raw_dps_xml)
      {
        xml:                compressed_xml,
        cnpj:               doc.at("Prestador CNPJ")&.text,
        municipioPrestador: doc.at("Prestador CodigoMunicipio")&.text
      }
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
```

---

### Step 8 — Spec

The VCR cassette body is `FAKE_BASE64_XML`. Stub `compressor.compress` to return exactly that so the request body matches the recorded cassette.

```ruby
# spec/services/nfse/issue_invoice_spec.rb
require "rails_helper"

RSpec.describe Nfse::IssueInvoice do
  let(:dps_xml)   { File.read(Rails.root.join("spec/fixtures/xml/dps_example.xml")) }
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
```

---

## Decision Notes

| Decision | Rationale |
|----------|-----------|
| Parse CNPJ/municipality from DPS XML | `invoice.company_cnpj` and `city_code` don't exist on the model; DPS XML already contains both |
| Dependency injection for all sub-services | Allows VCR cassette body matching (`FAKE_BASE64_XML`) and isolated testing without real crypto |
| Reuse `Result` class | Already used across the codebase; no new result object needed |
| Use HTTParty instead of Faraday | Already in Gemfile; supports mTLS via `:p12` option; avoids an extra dependency |
| All paths via ENV vars | `NFSE_SCHEMAS_PATH`, `NFSE_CERT_PATH`, `NFSE_CERT_PASSWORD`, `NFSE_API_URL` — production just sets different values, zero code changes |
| `Errors::ValidationError` new class | Distinguishes XML validation failures from gateway errors in rescue blocks |
| Sandi Metz compliant | All methods ≤5 work lines, ≤4 params — extracted `attach_signature`, `sign_and_compress`, `build_signed_info`, `build_reference`, `build_key_info` |

---

## Verification

```bash
# Install gems
bundle install

# Run the new service spec
bundle exec rspec spec/services/nfse/issue_invoice_spec.rb --format documentation

# Full suite — no regressions
bundle exec rspec
```

Expected: all green. `Nfse::IssueInvoice` spec reports success result, invoice attributes updated, and failure cases handled correctly.
