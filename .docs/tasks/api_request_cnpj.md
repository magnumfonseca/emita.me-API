# Implement Post‑Gov.br CNPJ Discovery via NFS‑e Nacional API (Rails 8)

## **Objective**
After the user authenticates via Gov.br OAuth2, your system must:

- Use the Gov.br access token to call the **NFS‑e Nacional “Contribuintes” API**.
- Retrieve all **CNPJs (establishments)** the authenticated CPF is authorized to act on behalf of.
- Persist these establishments in the database.
- Provide mocked API responses so VCR cassettes can be generated **without calling the real API**, since no production token or mTLS certificate is available yet.

---

## **Reference Documentation**
The official API documentation for this feature is available in the restricted Swagger environment:
**https://adn.producaorestrita.nfse.gov.br/contribuintes/docs/index.html**

This Swagger requires:

- Gov.br OAuth2 access token  
- mTLS (client certificate)  
- Access to the restricted environment  

Because of this, the endpoint cannot be accessed directly via browser.
---

## **Endpoint to Implement**
The endpoint that returns all CNPJs associated with the authenticated CPF is:

```
GET /contribuintes/v1/estabelecimentos
```

This endpoint belongs to the **Contribuintes API**, not the DPS/NFS‑e API described in the PDF.

---

## **Example HTTP Request (to include in the task)**

```http
GET https://adn.producaorestrita.nfse.gov.br/contribuintes/v1/estabelecimentos
Authorization: Bearer <GOVBR_ACCESS_TOKEN>
Accept: application/json
Content-Type: application/json
```

This request must be executed using:

- HTTPS  
- mTLS (client certificate + private key)  
- A valid Gov.br access token  

---

## **Example HTTP Response (mock for VCR)**

```json
{
  "cpf": "12345678900",
  "estabelecimentos": [
    {
      "cnpj": "12345678000199",
      "razaoSocial": "Empresa Exemplo LTDA",
      "nomeFantasia": "Exemplo",
      "municipio": "3550308",
      "uf": "SP",
      "perfis": ["EMISSOR", "CONSULTA"]
    },
    {
      "cnpj": "98765432000155",
      "razaoSocial": "Prestadora Serviços ME",
      "nomeFantasia": "Serviços ME",
      "municipio": "3304557",
      "uf": "RJ",
      "perfis": ["EMISSOR"]
    }
  ]
}
```
---

## **Data to Persist**
Each establishment returned by the API must be stored with:

- `cnpj`
- `razao_social`
- `nome_fantasia`
- `municipio_codigo`
- `uf`
- `perfis` (array)
- `user_id` (references to user)
- timestamps

Model name suggestion:

```ruby
class Establishment < ApplicationRecord
  belongs_to :user
  serialize :perfis, Array
end
```

---

## **Service to Implement**
Create:

```
FetchEstablishments
```

### Responsibilities
- Accept the Gov.br access token.
- Call the endpoint `/contribuintes/v1/estabelecimentos`.
- Parse the JSON response.
- Persist or update establishments.
- Return a structured result object.

### Public API

```ruby
result = Govbr::FetchEstablishments.call(access_token:)
```

### Result Object

```ruby
result.success?
result.establishments
result.error
```

---

## **HTTP Client Requirements**
- Use HTTParty.
- Configure mTLS (client certificate + private key)
  - Are we doing this on app/services/nfse/issue_invoice.rb? If so, should we abstract it?
- Inject the Gov.br access token into the Authorization header.
- Base URL must be configurable via ENV.

---

## **Mocking Requirements**
Because you do not have:

- a real Gov.br token  
- a real client certificate  
- access to the restricted environment  

Claude must:

1. Generate mock JSON fixtures.
2. Generate VCR cassettes using these mocks.
3. Ensure the service is fully testable offline.

### VCR cassette:

```
---
http_interactions:
- request:
    method: get
    uri: https://adn.producaorestrita.nfse.gov.br/contribuintes/v1/estabelecimentos
    body:
      encoding: UTF-8
      string: ""
    headers:
      Authorization:
      - Bearer FAKE_GOVBR_ACCESS_TOKEN
      Accept:
      - application/json
      Content-Type:
      - application/json
      User-Agent:
      - Faraday v2.7.0
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Type:
      - application/json
      Content-Length:
      - "345"
    body:
      encoding: UTF-8
      string: |
        {
          "cpf": "12345678900",
          "estabelecimentos": [
            {
              "cnpj": "12345678000199",
              "razaoSocial": "Empresa Exemplo LTDA",
              "nomeFantasia": "Exemplo",
              "municipio": "3550308",
              "uf": "SP",
              "perfis": ["EMISSOR", "CONSULTA"]
            },
            {
              "cnpj": "98765432000155",
              "razaoSocial": "Prestadora Serviços ME",
              "nomeFantasia": "Serviços ME",
              "municipio": "3304557",
              "uf": "RJ",
              "perfis": ["EMISSOR"]
            }
          ]
        }
  recorded_at: 2026-03-05 10:18:00 UTC
recorded_with: VCR 6.2.0l
```

---

## **RSpec Tests**
Claude must generate tests for:

- successful fetch  
- persistence of establishments  
- empty response  
- invalid token (mocked 401)  
- malformed response  

---

## **Integration With Existing Authentication Flow**
After Gov.br login, your system receives:

- `govbr_user_id`
- `govbr_access_token`

The new service must be called via an async job (Rails Active Job with Solid Queue) after authentication:  
