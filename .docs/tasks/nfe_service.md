# **Build the NFS-e National Issuance Service (Rails 8)**

## **Goal**  
Implement a complete Rails 8 service responsible for issuing a DPS (Declaração de Prestação de Serviços) to the **Official NFS‑e Nacional API**, using:

- a **fake test certificate**  
- a **fake DPS XML**  
- a **mocked API response** (VCR cassette)  
- the **official XSD schemas**  
- the **official API manual**  

This service will run in the test environment until real API credentials and the production “certificado técnico” are available.

---

## **Reference Materials (must be used)**

### Guidelines

use this repo guidelines: ./CLAUDE.md

### **1. Official API Manual (PDF)**  
Located at:  
`.docs/references/manual-contribuintes-emissor-publico-api-sistema-nacional-nfs-e-v1-2-out2025.pdf`

This manual defines:

- DPS XML structure  
- XMLDSig signature rules  
- GZip + Base64 compression rules  
- API endpoints  
- Request/response formats  
- Error codes  
- NFS‑e return XML structure  

### **2. Official XSD Schemas**  
Located at:  
`.docs/references/schemas/`

The service must validate XMLs using these four schemas:

- `DPS_v1.01.xsd`  
- `NFSe_v1.01.xsd`  
- `tiposComplexos_v1.01.xsd`  
- `xmldsig-core-schema.xsd`

These schemas define the structure of:

- the DPS XML sent to the API  
- the NFS‑e XML returned by the API  
- the XML signature block  
- all complex types used in the layouts  

---

## **Test Assets (must be used)**

### **1. Fake DPS XML**  
`spec/fixtures/xml/dps_example.xml`

### **2. Fake certificate (PKCS#12)**  
`spec/support/certs/test_cert.pfx`  
Password: `"123456"`

### **3. Mocked API response (VCR cassette)**  
`spec/vcr_cassettes/govbr/nfse_issue.yml`

The service must be fully compatible with this cassette.

---

## **Service Requirements**

### **Service name**
`app/services/nfse/issue_invoice.rb`

### **Public API**
```ruby
result = Nfse::IssueInvoice.call(invoice)
```

### **Expected behavior**
1. Load the DPS XML from `invoice.dps_xml` or from the fixture file in tests.  
2. Validate the XML against the XSDs in `.docs/references/schemas/`.  
3. Sign the XML using the fake certificate (`test_cert.pfx`) following XMLDSig rules from the manual.  
4. Compress the signed XML using **GZip**.  
5. Encode the compressed bytes using **Base64**.  
6. Build the JSON payload required by the NFS‑e Nacional API:  
   ```json
   {
     "xml": "<BASE64_STRING>",
     "cnpj": "<invoice.company_cnpj>",
     "municipioPrestador": "<invoice.city_code>"
   }
   ```
7. Send the request to `POST https://api.nfse.gov.br/nfse` using Faraday with mTLS:  
   - `client_cert` = certificate from `test_cert.pfx`  
   - `client_key` = private key from `test_cert.pfx`  
8. Parse the JSON response.  
9. Extract:  
   - `chaveAcesso`  
   - compressed XML of the NFS‑e  
10. Decompress and decode the returned XML.  
11. Validate the returned XML using the XSDs.  
12. Update the invoice record with:  
    - `access_key`  
    - `nfse_xml`  
    - `compressed_nfse_xml`  
    - `consultation_url` = `"https://www.nfse.gov.br/consulta/#{access_key}"`  
    - `status = :issued`  
13. Return a result object with:  
    - `success?`  
    - `invoice`  
    - `errors` (if any)

---

## **Technical Requirements**

### **XML Signature**
- Must follow XMLDSig rules from the official manual.  
- Use RSA‑SHA256.  
- Insert `<Signature>` block referencing the root element.  
- Include certificate information in `<KeyInfo>`.

### **Compression**
- Use `Zlib::Deflate` for GZip compression.  
- Use `Base64.strict_encode64` for encoding.

### **HTTP Client**
- Use Faraday.  
- Configure mTLS using the fake certificate.

### **Testing**
- All external HTTP calls must be wrapped by VCR.  
- The service must pass using the cassette:  
  `spec/vcr_cassettes/govbr/nfse_issue.yml`

### **Error Handling**
- If XML validation fails → return `success: false`  
- If signing fails → return `success: false`  
- If compression fails → return `success: false`  
- If HTTP request fails → return `success: false`  
- If response is missing `chaveAcesso` → return `success: false`  

---

## **Deliverables**

Claude must generate:

1. `app/services/nfse/issue_invoice.rb`  
2. `app/services/nfse/xml_signer.rb`  
3. `app/services/nfse/xml_compressor.rb`  
4. `app/services/nfse/xml_validator.rb` (using XSDs from `.docs/references/schemas/`)  
5. `app/services/nfse/client.rb` (Faraday + mTLS)  
6. RSpec tests using the provided VCR cassette  
7. A simple result object (e.g., `ServiceResult`)  
