Claro, Magnum — aqui está o **PRD totalmente traduzido para o inglês**, mantendo **todos os termos oficiais brasileiros do GOV.br** (como *Gov.br*, *NFS-e Nacional*, *DAS*, *MEI*, *PME*, *Simples Nacional*, *IBS*, *CBS*, etc.).  
Também preservei o tom original e a estrutura profissional do documento.

---

# 📄 PRD: Project “Simplifica MEI & PME”  
**Version:** 1.0 (MVP) | **Date:** February 2026  
**Status:** Concept Definition  

---

## 1. Overview (The “Why”)  
Brazilian microentrepreneurs spend, on average, 150 hours per year dealing solely with tax bureaucracy. With the 2026 Tax Reform and the mandatory adoption of the *NFS-e Nacional*, confusion around the new *IBS* and *CBS* rates has widened the gap between the government and small business owners.  

**Simplifica** emerges as the friendly interface that solves this in seconds.

---

## 2. Target Audience  
- **MEIs (Microempreendedores Individuais):** Service providers who need to issue invoices and pay the *DAS* without surprises.  
- **Early-stage PMEs:** Companies under the *Simples Nacional* that cannot yet afford a robust ERP or an expensive full-time accountant.  
- **“Non‑Tech Users”:** People who use WhatsApp as their primary work tool.

---

## 3. Functional Requirements (Features)

### 3.1. “Flash” Issuer for NFS-e Nacional  
- **Description:** Simplified interface to issue the *Nota Fiscal de Serviço Nacional*.  
- **Differential:** Save “Invoice Templates” (e.g., “English Class”, “Consulting”). The user taps the template, enters the amount, and the invoice is generated.  
- **2026 Rule:** The app must automatically calculate the transition to *IBS* and *CBS* according to the current table.

### 3.2. Tax Hub (“Pay Everything”)  
- **Description:** A single screen with the full schedule of due dates (*DAS*, Installments, Municipal Fees).  
- **Feature:** “Pay with Pix” button that generates the QR Code inside the app — no PDF download required.

### 3.3. Revenue Monitor (Excess Radar)  
- **Description:** A visual progress bar showing how much is left before reaching the MEI revenue cap (R$ 81,000 or the updated value).  
- **Notification:** Smart alerts when reaching 70%, 80%, and 90% of the cap.

### 3.4. WhatsApp Assistant (The Heart of the Product)  
- **Description:** An official bot where the user sends:  
  *“Issue an invoice of R$ 200 for João (CPF XXX)”*  
  and the bot replies with the link to the ready invoice.

---

## 4. Non‑Functional Requirements (Quality)  
- **Security:** Authentication via *Gov.br* account (mandatory for *NFS-e Nacional*) and biometric login in the app.  
- **Lightweight:** The app must be under 40MB and work well on unstable 4G networks.  
- **LGPD:** Full encryption of the end‑users’ client data.

---

## 5. Suggested Technical Architecture  

| Component | Suggested Technology |
|----------|----------------------|
| Frontend | Flutter or React Native (Multiplatform) |
| Backend | Node.js or Python (for agility) |
| Fiscal Integration | Third‑party APIs (e.g., Plugue, Focus NFe, Linker) |
| Database | PostgreSQL (robust for financial data) |
| Notifications | Firebase Cloud Messaging & WhatsApp Business API |

---

## 6. Business Model (Monetization)  
- **Freemium:** Free up to 3 invoices/month + expense tracking.  
- **Premium Subscription (R$ 29.90/month):** Unlimited invoices, WhatsApp issuance, and priority support.  
- **B2B / Partnerships:** Selling insurance and microcredit to users (commission‑based).

---

## 7. Success Criteria (KPIs)  
- **Average issuance time:** Under 45 seconds per invoice.  
- **Retention:** 60% of active users return the following month to pay the *DAS*.  
- **System Error Rate:** Less than 2% failures in communication with the *ADN (Ambiente Nacional)*.

---

## Suggested Next Step  
Would you like me to detail the **User Flow** (screen‑by‑screen journey) for issuing an invoice quickly inside the app?

---

# Backlog — Sprints Breakdown

## 🟢 Phase 1: Foundation & Setup (Week 1–2)  
Goal: Prepare the structure to receive fiscal data.  
- **Task 1.1:** Choose and contract the Fiscal Invoice API (e.g., Focus NFe, Plugue, or Linker) to avoid building direct government communication.  
- **Task 1.2:** Design Low‑Fidelity Wireframes for the 4 main screens: Home, Invoice Issuance, Tax Management, and Profile.  
- **Task 1.3:** Set up the development environment (GitHub repository and PostgreSQL database).

---

## 🔵 Phase 2: Authentication & Registration (Week 3–4)  
Without this, the user cannot access government data.  
- **Task 2.1:** Implement Login via *Gov.br* (mandatory integration to access the national invoice system).  
- **Task 2.2:** Create the Onboarding flow: Capture CNPJ, Company Name, and Tax Regime.  
- **Task 2.3:** Create the “Client Registry”: A simple database for users to save frequent invoice recipients.

---

## 🟡 Phase 3: The “Heart” — Invoice Issuance (Week 5–7)  
Where the product’s value becomes visible.  
- **Task 3.1:** Create a simplified issuance form (Amount + Client Selection + Service Description).  
- **Task 3.2:** Implement the 2026 Calculation Engine: Logic to automatically separate *IBS* and *CBS* according to the new rule.  
- **Task 3.3:** Generate the invoice PDF and enable “Share via WhatsApp”.  
- **Task 3.4:** Create “Invoice Templates” (Favorites) for 1‑click issuance.

---

## 🔴 Phase 4: Financial Management & DAS (Week 8–9)  
Prevent users from forgetting government payments.  
- **Task 4.1:** Integrate to automatically fetch the monthly *DAS‑MEI* boleto via API.  
- **Task 4.2:** Create the “Revenue Thermometer”: A visual bar summing all invoices issued in the year and comparing with the MEI limit.  
- **Task 4.3:** Implement Push Notifications:  
  *“Your DAS is due in 2 days. Pay now via Pix.”*

---

## 🟣 Phase 5: The Differentiator — WhatsApp Automation (Week 10–12)  
Where you win the market of “lazy‑efficient” users.  
- **Task 5.1:** Configure the official WhatsApp Business API.  
- **Task 5.2:** Create the Bot Flow:  
  *“Hello! Enter the invoice amount for [Client X].”*  
- **Task 5.3:** Test the integration:  
  Bot receives command → Backend processes invoice → Bot returns PDF/Link.

---

# 📊 MVP Priority Summary  

| Priority | Task | Why It Matters |
|----------|------|----------------|
| Critical | Invoice Issuance (NFS-e) | It’s the core reason the app exists. |
| High | IBS/CBS Calculation | Prevents fiscal errors during the 2026 transition. |
| Medium | DAS Management | Drives retention (user returns monthly). |
| Differentiator | WhatsApp Bot | Makes you superior to competitors. |

---
