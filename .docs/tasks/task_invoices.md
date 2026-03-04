Here is a clean, production‑ready **English task description** for your backlog.  
It defines exactly what needs to be built: the **migration** and the **model** for storing all NFS‑e National data (DPS, NFS‑e, access key, XML, PDF URL, consultation URL, status, etc.).

---

## 📝 Task: Create Migration and Model for Invoices (NFS-e National)

### **Goal**  
Implement the database structure and Rails model required to store all fiscal data related to NFS‑e National issuance, including DPS XML, NFS‑e XML, access key, consultation URL, PDF URL, tax values, and processing status.

---

## **Scope**

### **1. Create a new Rails model: `Invoice`**

The model must support the full lifecycle of a Brazilian NFS‑e National:

- Draft creation  
- DPS XML generation  
- Signed XML storage  
- API request/response tracking  
- NFS‑e XML storage  
- PDF generation and storage  
- Consultation link generation  
- Delivery to WhatsApp/email  

---

## **2. Create a migration with the following fields**

### **Identification**
- `user_id: references` — Owner of the invoice  
- `client_id: references` — Recipient of the service  
- `service_description: text`  
- `amount_cents: integer`  

### **Tax fields**
- `ibs_rate: decimal, precision: 5, scale: 4`  
- `cbs_rate: decimal, precision: 5, scale: 4`  
- `ibs_value_cents: integer`  
- `cbs_value_cents: integer`  

### **DPS (request)**
- `dps_xml: text` — Raw XML sent to the API  
- `signed_dps_xml: text` — XML after XMLDSig signature  
- `compressed_dps_xml: text` — GZip + Base64 version sent to the API  

### **NFS-e (response)**
- `access_key: string` — `chaveAcesso` returned by the API  
- `nfse_xml: text` — Decompressed XML of the NFS‑e  
- `compressed_nfse_xml: text` — Raw Base64 returned by the API  

### **URLs**
- `consultation_url: string` — `https://www.nfse.gov.br/consulta/{access_key}`  
- `pdf_url: string` — URL of the generated PDF stored in S3 or similar  

### **Status tracking**
- `status: string` — `draft`, `pending`, `issued`, `error`  
- `error_message: text` — API or validation error  
- `issued_at: datetime`  

### **Metadata**
- `raw_response: jsonb` — Full API response for audit  
- `timestamps`  

---

## **3. Add model validations and enums**

### **Status enum**
```ruby
enum status: {
  draft: "draft",
  pending: "pending",
  issued: "issued",
  error: "error"
}
```

### **Validations**
- presence: `user_id`, `client_id`, `amount_cents`, `service_description`  
- numericality: `amount_cents > 0`  
- optional: tax fields (calculated later)  

---

## **4. Add associations**
```ruby
belongs_to :user
belongs_to :client
```

---

## **5. Acceptance Criteria**

- Migration runs successfully and creates all required fields.  
- Model includes enums, validations, and associations.  
- The structure supports the full NFS‑e lifecycle:  
  - DPS XML generation  
  - XML signature  
  - Compression  
  - API submission  
  - NFS‑e XML storage  
  - PDF generation  
  - Consultation link generation  
- No missing fields required for fiscal compliance.  

**important** TDD first, use shoulda match expectations when possible.