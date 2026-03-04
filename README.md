# Emita.ME

Emita.me API is a backend service built with **Ruby on Rails 8 (API‑only)**, designed for issuing Brazilian electronic service invoices (NFS-e Nacional).
It uses **PostgreSQL** as the primary database, **RSpec** for automated testing, and runs inside a **Dev Container** to ensure a consistent development environment across machines.

---

## Features

- Rails 8 API‑only architecture
- PostgreSQL database
- JWT authentication
- Contacts management (CRUD)
- Invoice management with NFS-e Nacional issuance via `api.nfse.gov.br`
  - XML signing (XMLDSig RSA-SHA256)
  - XSD schema validation
  - mTLS client certificate authentication
  - GZip + Base64 compression
- RSpec test suite with VCR cassettes
- Dev Container support (VS Code / GitHub Codespaces)
- Modular service object architecture

---

## Tech Stack

| Component   | Technology             |
|-------------|------------------------|
| Backend     | Ruby on Rails 8        |
| Database    | PostgreSQL             |
| Testing     | RSpec, VCR, Webmock    |
| Auth        | JWT                    |
| HTTP Client | HTTParty (mTLS)        |
| XML         | Nokogiri               |
| Environment | Dev Container          |

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-username/emita-me.git
cd emita-me
```

### 2. Open in Dev Container

If you're using VS Code:

```
Ctrl + Shift + P → "Dev Containers: Reopen in Container"
```

The container will automatically install Ruby, Rails, PostgreSQL, and all project dependencies.

### 3. Configure environment variables

```bash
cp .env.example .env
```

Fill in the required values:

```
DATABASE_USERNAME=
DATABASE_PASSWORD=
DATABASE_HOST=
JWT_SECRET=

# NFS-e Nacional
NFSE_SCHEMAS_PATH=/absolute/path/to/.docs/references/schemas
NFSE_CERT_PATH=/absolute/path/to/cert.pfx
NFSE_CERT_PASSWORD=
NFSE_API_URL=https://api.nfse.gov.br/nfse
```

### 4. Set up the database

```bash
bin/rails db:create db:migrate
```

### 5. Run the test suite

```bash
bundle exec rspec
```

---

## NFS-e Issuance

Invoices are issued via `Nfse::IssueInvoice`, which orchestrates:

1. XSD validation of the DPS XML
2. XMLDSig RSA-SHA256 signing using a PKCS12 client certificate
3. GZip + Base64 compression
4. POST to `api.nfse.gov.br` with mTLS
5. Persistence of the returned NFS-e data on the `Invoice` record

```ruby
result = Nfse::IssueInvoice.call(invoice)
result.success? # => true
result.data     # => invoice (with access_key, nfse_xml, status: "issued")
```

All file paths and credentials are configured via ENV vars — no code changes are needed between environments.

### Test certificates

`spec/support/certs/` contains throwaway self-signed certificates used only for tests. They carry no real identity and are safe to commit. The VCR cassette at `spec/vcr_cassettes/govbr/nfse_issue.yml` records a fake API interaction so the suite runs without hitting the live endpoint.
