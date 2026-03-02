# Contacts Endpoint — Execution Plan

## Context

The Rails 8 API application already has a `Contact` model (with CPF/CNPJ/email/phone validations), a `User` model, and a Gov.br OAuth authentication flow. The auth callback returns user data but no token, so subsequent requests have no way to identify the current user. This plan implements:

1. **JWT token issuance** — modify the auth callback to return a signed JWT.
2. **Authentication concern** — decode the Bearer token on every protected request.
3. **Contacts CRUD** — `index`, `show`, `create`, `update`, `destroy` under `api/v1/contacts`.
4. **TDD order** — specs first, then implementation, then swaggerize + rubocop.

---

## Critical Files

| File | Action |
|------|--------|
| `app/controllers/auth/sessions_controller.rb` | Modify — return JWT token in success response |
| `config/routes.rb` | Modify — add `namespace :api > :v1 > resources :contacts` |
| `app/models/contact.rb` | Modify — add `by_name`, `by_cpf`, `by_cnpj` scopes |
| `app/controllers/concerns/authenticatable.rb` | Create — JWT decode, `current_user`, `authenticate_user!` |
| `app/serializers/contact_serializer.rb` | Create — JSONAPI::Serializer for contacts |
| `app/controllers/api/v1/contacts_controller.rb` | Create — CRUD controller (index, show, create, update, destroy) |
| `spec/requests/api/v1/contacts_spec.rb` | Create — rswag request specs (TDD first) |

---

## Response Format (all contacts endpoints)

```json
// Success
{ "success": true, "data": { ... }, "message": "..." }

// Success (index with pagination)
{ "success": true, "data": [...], "meta": { "current_page": 1, "total_pages": 3, "total_count": 47 }, "message": null }

// Error
{ "success": false, "data": null, "error": { "code": "VALIDATION_ERROR", "message": "...", "details": ["..."] } }
```

`data` for a single contact uses `ContactSerializer.new(contact).serializable_hash[:data]` (JSONAPI format: `id`, `type`, `attributes`).

---

## Spec Scenarios

### index (7)
1. Returns paginated list for page 1
2. Returns paginated list for page 2
3. Returns empty list when user has no contacts
4. Filters by name
5. Filters by cpf
6. Filters by cnpj
7. Returns empty when filter has no match

### show (2)
1. Returns a contact
2. Returns 404 when contact is not found

### create (7)
1. Creates a contact with name, email, cpf
2. Creates a contact with name, phone, cnpj
3. Returns error when name is empty
4. Returns error when cpf and cnpj are empty
5. Returns error when email and phone are empty
6. Returns error when cpf is invalid
7. Returns error when cnpj is invalid

### update (3)
1. Update successful
2. Update error: cpf/cnpj invalid
3. Update error: removes phone or email leaving both empty

### destroy (2)
1. Returns success when deleting a found contact
2. Returns success when deleting a not found contact (idempotent)

---

## Implementation Steps

### Step 1 — Write rswag request spec (TDD first)
**File:** `spec/requests/api/v1/contacts_spec.rb`

Use a helper to generate a valid JWT Bearer token for the test user.

### Step 2 — Create `Authenticatable` concern
**File:** `app/controllers/concerns/authenticatable.rb`

- `authenticate_user!` — validates Bearer token, renders 401 if invalid
- `current_user` — decodes JWT, memoizes User record
- `find_user_from_token` — decodes JWT from `Authorization` header
- `render_unauthorized` — renders tuple error response with `UNAUTHORIZED` code

JWT secret from `ENV.fetch("JWT_SECRET")`. Algorithm: `HS256`.

### Step 3 — Modify `Auth::SessionsController`
**File:** `app/controllers/auth/sessions_controller.rb`

Change `render_success` to generate and return a JWT token alongside user data:
- `token: JWT.encode({ user_id: user.id }, ENV.fetch("JWT_SECRET"), "HS256")`
- Wrap response in tuple format: `{ success: true, data: ..., token: ..., message: ... }`

### Step 4 — Add filter scopes to `Contact` model
**File:** `app/models/contact.rb`

```ruby
scope :by_name,  ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }
scope :by_cpf,   ->(cpf)  { where(cpf: cpf.gsub(/\D/, "")) if cpf.present? }
scope :by_cnpj,  ->(cnpj) { where(cnpj: cnpj.gsub(/\D/, "")) if cnpj.present? }
```

### Step 5 — Create `ContactSerializer`
**File:** `app/serializers/contact_serializer.rb`

```ruby
class ContactSerializer
  include JSONAPI::Serializer
  attributes :name, :email, :cpf, :cnpj, :phone
end
```

### Step 6 — Create `Api::V1::ContactsController`
**File:** `app/controllers/api/v1/contacts_controller.rb`

Actions: `index`, `show`, `create`, `update`, `destroy`. Protected by `include Authenticatable`. Uses `current_user.contacts` scope for all queries. Renders tuple responses.

### Step 7 — Update Routes
**File:** `config/routes.rb`

```ruby
namespace :api do
  namespace :v1 do
    resources :contacts, only: [:index, :show, :create, :update, :destroy]
  end
end
```

### Step 8 — Swaggerize & Rubocop
```bash
rake rswag:specs:swaggerize
rubocop
```

---

## Error Codes Reference

| Code | HTTP Status | Trigger |
|------|------------|---------|
| `UNAUTHORIZED` | 401 | Missing or invalid JWT |
| `NOT_FOUND` | 404 | Contact not found for current user |
| `VALIDATION_ERROR` | 422 | Model validation failure |

---

## Verification

1. `bundle exec rspec spec/requests/api/v1/contacts_spec.rb` — all green
2. `rake rswag:specs:swaggerize` — `swagger/v1/swagger.yaml` updated with contacts paths
3. `rubocop` — zero offenses
