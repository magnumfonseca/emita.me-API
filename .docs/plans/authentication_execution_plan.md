# Gov.br Authentication — Execution Plan (TDD)

## OAuth 2.0 Flow

```
Frontend                      Backend                     Gov.br SSO
    |                             |                            |
    |-- (1) redirect user ------->|                            |
    |                             |-- (2) GET /authorize ----->|
    |                             |                            |
    |<----- (3) user logs in -----|<---------- redirect -------|
    |                             |                            |
    | (4) POST /auth/callback     |                            |
    |   { code: "..." } -------->|                            |
    |                             |-- (5) POST /token -------->|
    |                             |<-- (6) { id_token, ... } --|
    |                             |                            |
    |                             | (7) Decode JWT id_token    |
    |                             | (8) Validate trust level   |
    |                             | (9) Find or create User    |
    |                             |                            |
    |<-- (10) Response (user) ----|                            |
```

## Trust Level Requirements

| Level  | Allowed? | Notes                             |
|--------|----------|-----------------------------------|
| ouro   | Yes      | Highest level, biometric          |
| prata  | Yes      | Silver, required minimum          |
| bronze | No       | Insufficient — returns 403        |

## Environment Variables

| Variable              | Description                                       |
|-----------------------|---------------------------------------------------|
| `GOVBR_CLIENT_ID`     | OAuth client ID from Gov.br registration          |
| `GOVBR_CLIENT_SECRET` | OAuth client secret                               |
| `GOVBR_REDIRECT_URI`  | Callback URI registered with Gov.br               |
| `GOVBR_TOKEN_URL`     | Token endpoint (default: sso.acesso.gov.br/token) |

## Architecture

```
Auth::SignInService.new(code:, gateway: GovBr::OauthGateway.new).call
  └── GovBr::OauthGateway#fetch_token(code:)  → OauthResponse (value object)
        └── raises Errors::GatewayError        → when HTTP 5xx
  └── OauthResponse#valid?                     → checks trust level (prata/ouro)
  └── find_or_create_user(oauth_response)      → User (entity)
  └── Result.success(user)                     → or Result.failure("...")
```

**Layer responsibilities:**

- The **Gateway** performs the HTTP request and maps the raw response into an `OauthResponse` value object. Raises `Errors::GatewayError` on HTTP 5xx. Has no knowledge of success/failure business semantics.
- The **Service** calls the gateway, validates the `OauthResponse`, coordinates with the `User` model, and returns a `Result`. Rescues `Errors::GatewayError` from the gateway.
- The **Controller** branches on `result.success?` and maps error strings to HTTP status codes.

---

## TDD Execution Order

### Phase 1 — Write failing specs (RED)

1. Create VCR cassettes under `spec/vcr_cassettes/govbr/`
2. `spec/lib/oauth_response_spec.rb` — value object, no dependencies
3. `spec/gateways/gov_br/oauth_gateway_spec.rb` — gateway with VCR
4. `spec/services/auth/sign_in_service_spec.rb` — service with gateway double
5. `spec/requests/auth/sessions_spec.rb` — full HTTP integration (rswag)

### Phase 2 — Implement to pass specs (GREEN)

1. Migration + `app/models/user.rb`
2. `app/lib/errors/insufficient_trust_level.rb`
3. `app/gateways/gov_br/oauth_gateway.rb`
4. `app/services/auth/sign_in_service.rb`
5. `app/serializers/user_serializer.rb`
6. `app/controllers/auth/sessions_controller.rb`
7. `config/routes.rb` — add `post 'auth/callback'`

---

## VCR Cassettes

**Location:** `spec/vcr_cassettes/govbr/` (matches `config.cassette_library_dir = "spec/vcr_cassettes"` in `spec/support/vcr.rb`)

> ⚠️ **JWT fix:** The `id_token` payloads must use `"confiabilidade"` (not `"confiabilida"`) to match `OauthResponse#initialize` which calls `payload.dig("confiabilidade", "nivel")`.

### Generating JWT tokens for cassettes

Since tokens are decoded without signature verification (`JWT.decode(id_token, nil, false)`), generate test tokens in a Rails console:

```ruby
require 'base64'
header = "eyJhbGciOiJIUzI1NiJ9"

prata_payload = Base64.urlsafe_encode64(
  { sub: "12345678900", name: "Joao da Silva", email: "joao@example.com",
    confiabilidade: { nivel: "prata" } }.to_json, padding: false
)
prata_token = "#{header}.#{prata_payload}.signature"

bronze_payload = Base64.urlsafe_encode64(
  { sub: "98765432100", name: "Maria Bronze", email: "maria@example.com",
    confiabilidade: { nivel: "bronze" } }.to_json, padding: false
)
bronze_token = "#{header}.#{bronze_payload}.signature"
```

### `spec/vcr_cassettes/govbr/success.yml`

```yaml
http_interactions:
- request:
    method: post
    uri: https://sso.acesso.gov.br/token
    body:
      encoding: UTF-8
      string: ''
    headers:
      Content-Type:
      - application/x-www-form-urlencoded
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Type:
      - application/json
    body:
      encoding: UTF-8
      string: >
        {
          "access_token": "ACCESS_TOKEN_EXEMPLO",
          "id_token": "<JWT_PRATA_TOKEN>",
          "token_type": "Bearer",
          "expires_in": 3600,
          "scope": "openid email profile govbr_confiabilidades govbr_confiabilidades_idtoken"
        }
recorded_with: VCR 6.2.0
```

Replace `<JWT_PRATA_TOKEN>` with the output of `prata_token` from the generator above.

### `spec/vcr_cassettes/govbr/bronze.yml`

Same structure as `success.yml` — HTTP 200, but `id_token` uses `<JWT_BRONZE_TOKEN>` (bronze payload).

### `spec/vcr_cassettes/govbr/server_error.yml`

```yaml
http_interactions:
- request:
    method: post
    uri: https://sso.acesso.gov.br/token
    body:
      encoding: UTF-8
      string: ''
    headers:
      Content-Type:
      - application/x-www-form-urlencoded
  response:
    status:
      code: 500
      message: Internal Server Error
    headers:
      Content-Type:
      - application/json
    body:
      encoding: UTF-8
      string: >
        {
          "error": "server_error",
          "error_description": "Ocorreu um erro inesperado no servidor de autenticação."
        }
recorded_with: VCR 6.2.0
```

---

## Spec Files

### `spec/lib/oauth_response_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OauthResponse do
  let(:header) { "eyJhbGciOiJIUzI1NiJ9" }

  let(:prata_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "12345678900", name: "Joao da Silva", email: "joao@example.com",
        confiabilidade: { nivel: "prata" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:ouro_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "12345678900", name: "Joao da Silva", email: "joao@example.com",
        confiabilidade: { nivel: "ouro" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:bronze_token) do
    payload = Base64.urlsafe_encode64(
      { sub: "98765432100", name: "Maria Bronze", email: "maria@example.com",
        confiabilidade: { nivel: "bronze" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  let(:no_cpf_token) do
    payload = Base64.urlsafe_encode64(
      { sub: nil, name: "No CPF", email: "nocpf@example.com",
        confiabilidade: { nivel: "prata" } }.to_json, padding: false
    )
    "#{header}.#{payload}.signature"
  end

  describe "#cpf" do
    it "extracts sub from JWT payload" do
      expect(described_class.new(id_token: prata_token).cpf).to eq("12345678900")
    end
  end

  describe "#name" do
    it "extracts name from JWT payload" do
      expect(described_class.new(id_token: prata_token).name).to eq("Joao da Silva")
    end
  end

  describe "#email" do
    it "extracts email from JWT payload" do
      expect(described_class.new(id_token: prata_token).email).to eq("joao@example.com")
    end
  end

  describe "#trust_level" do
    it "extracts nivel from confiabilidade" do
      expect(described_class.new(id_token: prata_token).trust_level).to eq("prata")
    end
  end

  describe "#valid?" do
    it "returns true when trust level is prata" do
      expect(described_class.new(id_token: prata_token)).to be_valid
    end

    it "returns true when trust level is ouro" do
      expect(described_class.new(id_token: ouro_token)).to be_valid
    end

    it "returns false when trust level is bronze" do
      expect(described_class.new(id_token: bronze_token)).not_to be_valid
    end

    it "returns false when cpf is nil" do
      expect(described_class.new(id_token: no_cpf_token)).not_to be_valid
    end
  end
end
```

### `spec/gateways/gov_br/oauth_gateway_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GovBr::OauthGateway do
  subject(:gateway) { described_class.new }

  describe "#fetch_token" do
    context "when Gov.br returns 200 with prata user",
            vcr: { cassette_name: "govbr/success" } do
      it "returns an OauthResponse" do
        expect(gateway.fetch_token(code: "auth_code")).to be_a(OauthResponse)
      end

      it "returns a valid response" do
        expect(gateway.fetch_token(code: "auth_code")).to be_valid
      end

      it "maps cpf from the JWT sub claim" do
        expect(gateway.fetch_token(code: "auth_code").cpf).to eq("12345678900")
      end
    end

    context "when Gov.br returns 200 with bronze user",
            vcr: { cassette_name: "govbr/bronze" } do
      it "returns an OauthResponse" do
        expect(gateway.fetch_token(code: "auth_code")).to be_a(OauthResponse)
      end

      it "returns an invalid response" do
        expect(gateway.fetch_token(code: "auth_code")).not_to be_valid
      end
    end

    context "when Gov.br returns 500",
            vcr: { cassette_name: "govbr/server_error" } do
      it "raises Errors::GatewayError" do
        expect { gateway.fetch_token(code: "auth_code") }
          .to raise_error(Errors::GatewayError)
      end
    end
  end
end
```

### `spec/services/auth/sign_in_service_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::SignInService do
  let(:prata_oauth) do
    instance_double(OauthResponse,
      valid?: true, cpf: "12345678900",
      name: "Joao da Silva", email: "joao@example.com")
  end
  let(:bronze_oauth) { instance_double(OauthResponse, valid?: false) }
  let(:gateway)      { instance_double(GovBr::OauthGateway) }

  subject(:service)  { described_class.new(code: "auth_code", gateway: gateway) }

  describe "#call" do
    context "when trust level is prata" do
      before { allow(gateway).to receive(:fetch_token).and_return(prata_oauth) }

      it "returns Result.success" do
        expect(service.call).to be_success
      end

      it "creates a new user for the CPF" do
        expect { service.call }.to change(User, :count).by(1)
      end

      it "returns the user in result.data" do
        result = service.call
        expect(result.data).to be_a(User)
        expect(result.data.cpf).to eq("12345678900")
      end

      it "does not create a duplicate when CPF is already registered" do
        create(:user, cpf: "12345678900")
        expect { service.call }.not_to change(User, :count)
      end

      it "returns the existing user when CPF is already registered" do
        existing = create(:user, cpf: "12345678900")
        expect(service.call.data).to eq(existing)
      end
    end

    context "when trust level is bronze" do
      before { allow(gateway).to receive(:fetch_token).and_return(bronze_oauth) }

      it "returns Result.failure" do
        expect(service.call).to be_failure
      end

      it "sets error to insufficient_trust_level" do
        expect(service.call.error).to eq("insufficient_trust_level")
      end

      it "does not create a user" do
        expect { service.call }.not_to change(User, :count)
      end
    end

    context "when Gov.br is down" do
      before { allow(gateway).to receive(:fetch_token).and_raise(Errors::GatewayError) }

      it "returns Result.failure" do
        expect(service.call).to be_failure
      end

      it "sets error to gateway_error" do
        expect(service.call.error).to eq("gateway_error")
      end
    end
  end
end
```

### `spec/requests/auth/sessions_spec.rb`

```ruby
# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth::Sessions', type: :request do
  path '/auth/callback' do
    post 'Authenticate with Gov.br OAuth code' do
      tags        'Authentication'
      consumes    'application/json'
      produces    'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          code: { type: :string, description: 'Authorization code from Gov.br' }
        },
        required: ['code']
      }

      response '201', 'successful login — prata or ouro user' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id:         { type: :string },
                     type:       { type: :string },
                     attributes: {
                       type: :object,
                       properties: {
                         name:  { type: :string },
                         email: { type: :string },
                         cpf:   { type: :string }
                       }
                     }
                   }
                 }
               }

        let(:user) { create(:user) }
        let(:body) { { code: 'valid_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.success(user))
        end

        run_test!
      end

      response '403', 'insufficient trust level (bronze user)' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'insufficient_trust_level' }
               }

        let(:body) { { code: 'bronze_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("insufficient_trust_level"))
        end

        run_test!
      end

      response '503', 'Gov.br unavailable' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'gateway_error' }
               }

        let(:body) { { code: 'any_code' } }

        before do
          allow_any_instance_of(Auth::SignInService)
            .to receive(:call)
            .and_return(Result.failure("gateway_error"))
        end

        run_test!
      end
    end
  end
end
```

---

## Implementation Files

### 1. Migration — `db/migrate/TIMESTAMP_create_users.rb`

```ruby
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :cpf,   null: false
      t.string :name
      t.string :email

      t.timestamps
    end

    add_index :users, :cpf, unique: true
  end
end
```

### 2. `app/models/user.rb`

```ruby
class User < ApplicationRecord
  validates :cpf, presence: true, uniqueness: true
end
```

### 3. `app/lib/errors/insufficient_trust_level.rb`

```ruby
# frozen_string_literal: true

module Errors
  class InsufficientTrustLevel < StandardError; end
end
```

### 4. `app/gateways/gov_br/oauth_gateway.rb`

```ruby
# frozen_string_literal: true

module GovBr
  class OauthGateway
    TOKEN_URL = "https://sso.acesso.gov.br/token".freeze

    def fetch_token(code:)
      response = HTTParty.post(TOKEN_URL, body: token_params(code))
      raise Errors::GatewayError if response.server_error?

      OauthResponse.new(id_token: response.parsed_response["id_token"])
    end

    private

    def token_params(code)
      {
        grant_type:    "authorization_code",
        code:          code,
        redirect_uri:  ENV.fetch("GOVBR_REDIRECT_URI"),
        client_id:     ENV.fetch("GOVBR_CLIENT_ID"),
        client_secret: ENV.fetch("GOVBR_CLIENT_SECRET")
      }
    end
  end
end
```

### 5. `app/services/auth/sign_in_service.rb`

```ruby
# frozen_string_literal: true

module Auth
  class SignInService
    def initialize(code:, gateway: GovBr::OauthGateway.new)
      @code    = code
      @gateway = gateway
    end

    def call
      oauth_response = @gateway.fetch_token(code: @code)
      return Result.failure("insufficient_trust_level") unless oauth_response.valid?

      user = find_or_create_user(oauth_response)
      Result.success(user)
    rescue Errors::GatewayError
      Result.failure("gateway_error")
    end

    private

    def find_or_create_user(oauth_response)
      User.find_or_create_by!(cpf: oauth_response.cpf) do |u|
        u.name  = oauth_response.name
        u.email = oauth_response.email
      end
    end
  end
end
```

### 6. `app/serializers/user_serializer.rb`

```ruby
# frozen_string_literal: true

class UserSerializer
  include JSONAPI::Serializer

  attributes :name, :email, :cpf
end
```

### 7. `app/controllers/auth/sessions_controller.rb`

```ruby
# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    ERROR_STATUS_MAP = {
      "insufficient_trust_level" => :forbidden,
      "gateway_error"            => :service_unavailable
    }.freeze

    def create
      result = Auth::SignInService.new(code: params[:code]).call
      result.success? ? render_success(result.data) : render_failure(result.error)
    end

    private

    def render_success(user)
      render json: UserSerializer.new(user).serializable_hash, status: :created
    end

    def render_failure(error)
      render json: { error: error }, status: ERROR_STATUS_MAP[error]
    end
  end
end
```

### 8. `config/routes.rb`

```ruby
Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :auth do
    post 'callback', to: 'sessions#create'
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

## Service Responses

| Scenario             | Result                                          | HTTP  |
|----------------------|-------------------------------------------------|-------|
| Success (prata/ouro) | `Result.success(user)`                          | 201   |
| Bronze level         | `Result.failure("insufficient_trust_level")`    | 403   |
| Gov.br 5xx           | `Result.failure("gateway_error")`               | 503   |

## Key Files

| File                                              | Layer            | Status   | Role                                           |
|---------------------------------------------------|------------------|----------|------------------------------------------------|
| `app/controllers/auth/sessions_controller.rb`     | Interface Adapter | create   | HTTP entry point, renders response             |
| `app/services/auth/sign_in_service.rb`            | Use Case          | create   | Orchestrates gateway + User creation           |
| `app/gateways/gov_br/oauth_gateway.rb`            | Interface Adapter | create   | HTTParty adapter for Gov.br token API          |
| `app/lib/oauth_response.rb`                       | Value Object      | exists   | Decodes JWT, exposes cpf/name/email/trust_level |
| `app/lib/result.rb`                               | Value Object      | exists   | Standard success/failure wrapper               |
| `app/lib/errors/gateway_error.rb`                 | Error             | exists   | Raised by gateway on HTTP 5xx                  |
| `app/lib/errors/insufficient_trust_level.rb`      | Error             | create   | Raised for bronze trust level                  |
| `app/serializers/user_serializer.rb`              | Interface Adapter | create   | Shapes User into JSON output                   |
| `app/models/user.rb`                              | Entity            | create   | ActiveRecord user with CPF unique index        |
| `spec/lib/oauth_response_spec.rb`                 | Spec              | create   | Value object unit tests                        |
| `spec/gateways/gov_br/oauth_gateway_spec.rb`      | Spec              | create   | Gateway VCR tests                              |
| `spec/services/auth/sign_in_service_spec.rb`      | Spec              | create   | Service unit tests with gateway double         |
| `spec/requests/auth/sessions_spec.rb`             | Spec              | create   | Full HTTP integration + rswag documentation    |
| `spec/vcr_cassettes/govbr/success.yml`            | Cassette          | create   | Gov.br 200 with prata user                     |
| `spec/vcr_cassettes/govbr/bronze.yml`             | Cassette          | create   | Gov.br 200 with bronze user                    |
| `spec/vcr_cassettes/govbr/server_error.yml`       | Cassette          | create   | Gov.br 500 error                               |

## Factory

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    cpf   { Faker::Number.number(digits: 11).to_s }
    name  { Faker::Name.full_name }
    email { Faker::Internet.email }
  end
end
```

## References

- Gov.br technical guide: https://acesso.gov.br/roteiro-tecnico/iniciarintegracao.html
- Token endpoint: `https://sso.acesso.gov.br/token`
- Required scopes: `openid email profile govbr_confiabilidades govbr_confiabilidades_idtoken`
