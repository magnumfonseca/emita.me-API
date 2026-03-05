# Execution Plan: Retrieve Establishments via NFS-e Contribuintes API

## Context

After Gov.br OAuth2 authentication, the system must discover all CNPJs the authenticated
CPF is authorized to act on. This calls `GET /contribuintes/v1/estabelecimentos`, persists
results, and runs asynchronously after sign-in. Real API requires mTLS + production token,
so tests are driven entirely by VCR cassettes with handcrafted mock responses.

---

## TDD Implementation Order

Each component follows: **write spec first → implement to pass**.

---

### Step 1: Migration

**File:** `db/migrate/<ts>_create_establishments.rb`

```ruby
create_table :establishments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
  t.references :user, type: :uuid, null: false, foreign_key: true
  t.string  :cnpj,             null: false
  t.string  :razao_social,     null: false
  t.string  :nome_fantasia
  t.string  :municipio_codigo
  t.string  :uf
  t.text    :perfis, array: true, default: []
  t.boolean :authorized, null: false, default: false
  t.timestamps
end
add_index :establishments, [:user_id, :cnpj], unique: true
```

Run: `bin/rails db:migrate`

---

### Step 2: Factory

**File:** `spec/factories/establishments.rb`

Needed before any spec can build records.

```ruby
FactoryBot.define do
  factory :establishment do
    association :user
    cnpj             { "12345678000199" }
    razao_social     { "Empresa Exemplo LTDA" }
    nome_fantasia    { "Exemplo" }
    municipio_codigo { "3550308" }
    uf               { "SP" }
    perfis           { ["EMISSOR", "CONSULTA"] }

    trait :consulta_only do
      perfis { ["CONSULTA"] }
    end
  end
end
```

---

### Step 3: Model spec → Model implementation

#### 3a. Write spec first

**File:** `spec/models/establishment_spec.rb`

```ruby
RSpec.describe Establishment do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:cnpj) }
    it { is_expected.to validate_presence_of(:razao_social) }
    it { is_expected.to validate_uniqueness_of(:cnpj).scoped_to(:user_id) }
  end

  describe "before_save :set_authorized" do
    it "sets authorized true when perfis includes EMISSOR" do
      e = build(:establishment, perfis: ["EMISSOR", "CONSULTA"])
      e.save!
      expect(e.authorized).to be true
    end

    it "sets authorized false when perfis does not include EMISSOR" do
      e = build(:establishment, :consulta_only)
      e.save!
      expect(e.authorized).to be false
    end

    it "updates authorized on re-save when perfis change" do
      e = create(:establishment, perfis: ["EMISSOR"])
      e.update!(perfis: ["CONSULTA"])
      expect(e.reload.authorized).to be false
    end
  end
end
```

#### 3b. Implement model

**File:** `app/models/establishment.rb`

```ruby
class Establishment < ApplicationRecord
  belongs_to :user

  validates :cnpj, presence: true, cnpj: true, uniqueness: { scope: :user_id }
  validates :razao_social, presence: true

  before_save :set_authorized

  private

  def set_authorized
    self.authorized = perfis.include?("EMISSOR")
  end
end
```

---

### Step 4: VCR Cassettes

Handcrafted YAML files — created before service specs so tests can reference them.
Use `<BEARER_TOKEN>` placeholder (matches VCR `filter_sensitive_data` in `spec/support/vcr.rb`).

**Files to create:**

- `spec/vcr_cassettes/govbr/fetch_establishments_success.yml` — 200 with 2 establishments
- `spec/vcr_cassettes/govbr/fetch_establishments_empty.yml` — 200 with empty array
- `spec/vcr_cassettes/govbr/fetch_establishments_unauthorized.yml` — 401
- `spec/vcr_cassettes/govbr/fetch_establishments_server_error.yml` — 500

Success cassette body:
```json
{
  "cpf": "12345678900",
  "estabelecimentos": [
    {"cnpj":"12345678000199","razaoSocial":"Empresa Exemplo LTDA","nomeFantasia":"Exemplo","municipio":"3550308","uf":"SP","perfis":["EMISSOR","CONSULTA"]},
    {"cnpj":"98765432000155","razaoSocial":"Prestadora Servicos ME","nomeFantasia":"Servicos ME","municipio":"3304557","uf":"RJ","perfis":["EMISSOR"]}
  ]
}
```

---

### Step 5: Service & Client spec → Implementation

#### 5a. Write service spec first

**File:** `spec/services/gov_br/fetch_establishments_spec.rb`

Use injected client doubles to avoid real HTTP calls.

```ruby
RSpec.describe GovBr::FetchEstablishments do
  let(:user)   { create(:user) }
  let(:client) { instance_double(GovBr::ContribuintesClient) }

  subject(:service) { described_class.new(user: user, access_token: "FAKE", client: client) }

  describe "#call" do
    context "when API returns establishments" do
      before { allow(client).to receive(:fetch_establishments).and_return(success_response) }

      it "returns Result.success" do
        expect(service.call).to be_success
      end

      it "persists all establishments" do
        expect { service.call }.to change(Establishment, :count).by(2)
      end

      it "sets authorized true for establishments with EMISSOR" do
        service.call
        expect(Establishment.find_by(cnpj: "12345678000199").authorized).to be true
      end

      it "upserts on re-fetch without duplicating records" do
        service.call
        expect { service.call }.not_to change(Establishment, :count)
      end
    end

    context "when API returns empty list" do
      before { allow(client).to receive(:fetch_establishments).and_return(empty_response) }

      it "returns Result.success with empty array" do
        result = service.call
        expect(result).to be_success
        expect(result.data).to eq([])
      end
    end

    context "when API returns 401" do
      before { allow(client).to receive(:fetch_establishments).and_return(unauthorized_response) }

      it "returns Result.failure(\"unauthorized\")" do
        expect(service.call.error).to eq("unauthorized")
      end
    end

    context "when API returns 500" do
      before { allow(client).to receive(:fetch_establishments).and_return(server_error_response) }

      it "returns Result.failure(\"gateway_error\")" do
        expect(service.call.error).to eq("gateway_error")
      end
    end
  end
end
```

#### 5b. Implement `GovBr::ContribuintesClient`

**File:** `app/gateways/gov_br/contribuintes_client.rb`

Mirrors `app/services/nfse/client.rb` (HTTParty + mTLS).
Reuses `NFSE_CERT_PATH` / `NFSE_CERT_PASSWORD` env vars (same certificate).
`GOVBR_CONTRIBUINTES_API_URL` env var for base URL configurability.

```ruby
module GovBr
  class ContribuintesClient
    include HTTParty

    def initialize(access_token:,
                   cert_path: ENV.fetch("NFSE_CERT_PATH"),
                   cert_password: ENV.fetch("NFSE_CERT_PASSWORD"))
      @access_token  = access_token
      @cert_path     = cert_path
      @cert_password = cert_password
    end

    def fetch_establishments
      self.class.get(
        "#{base_url}/contribuintes/v1/estabelecimentos",
        headers:      request_headers,
        p12:          File.read(@cert_path),
        p12_password: @cert_password
      )
    end

    private

    def base_url
      ENV.fetch("GOVBR_CONTRIBUINTES_API_URL", "https://adn.producaorestrita.nfse.gov.br")
    end

    def request_headers
      {
        "Authorization" => "Bearer #{@access_token}",
        "Accept"        => "application/json",
        "Content-Type"  => "application/json"
      }
    end
  end
end
```

#### 5c. Implement `GovBr::FetchEstablishments`

**File:** `app/services/gov_br/fetch_establishments.rb`

Single-action `.call` service (same pattern as `Auth::SignInService`).
`authorized` is set automatically by the model's `before_save` callback.

```ruby
module GovBr
  class FetchEstablishments
    def self.call(user:, access_token:, client: nil)
      new(user: user, access_token: access_token, client: client).call
    end

    def initialize(user:, access_token:, client: nil)
      @user   = user
      @client = client || GovBr::ContribuintesClient.new(access_token: access_token)
    end

    def call
      response = @client.fetch_establishments
      return Result.failure("gateway_error") if response.server_error?
      return Result.failure("unauthorized")  if response.unauthorized?

      Result.success(persist_establishments(parse(response)))
    rescue StandardError => e
      Result.failure(e.message)
    end

    private

    def parse(response)
      response.parsed_response.fetch("estabelecimentos", [])
    end

    def persist_establishments(data)
      data.map { |attrs| upsert(attrs) }
    end

    def upsert(attrs)
      Establishment.find_or_initialize_by(user: @user, cnpj: attrs["cnpj"]).tap do |e|
        e.update!(
          razao_social:     attrs["razaoSocial"],
          nome_fantasia:    attrs["nomeFantasia"],
          municipio_codigo: attrs["municipio"],
          uf:               attrs["uf"],
          perfis:           attrs["perfis"] || []
        )
      end
    end
  end
end
```

---

### Step 6: Job spec → Job implementation

#### 6a. Write job spec first

**File:** `spec/jobs/fetch_establishments_job_spec.rb`

```ruby
RSpec.describe FetchEstablishmentsJob do
  let(:user) { create(:user) }

  it "calls GovBr::FetchEstablishments with the correct arguments" do
    allow(GovBr::FetchEstablishments).to receive(:call)
    described_class.new.perform(user.id, "FAKE_TOKEN")
    expect(GovBr::FetchEstablishments).to have_received(:call)
      .with(user: user, access_token: "FAKE_TOKEN")
  end

  it "is enqueued on the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
```

#### 6b. Implement job

**File:** `app/jobs/fetch_establishments_job.rb`

Uses ActiveJob with `solid_queue` backend (already in Gemfile — no Sidekiq needed).

```ruby
class FetchEstablishmentsJob < ApplicationJob
  queue_as :default

  def perform(user_id, access_token)
    user = User.find(user_id)
    GovBr::FetchEstablishments.call(user: user, access_token: access_token)
  end
end
```

---

### Step 7: Integration — enqueue job after sign-in

The controller needs the raw `access_token` from Gov.br. Currently `Auth::SignInService`
returns `Result.success(user)` and `OauthResponse` only exposes `id_token`. Requires:

#### 7a. `app/lib/oauth_response.rb`
Expose `access_token` from the Gov.br `/token` response.

#### 7b. `app/services/auth/sign_in_service.rb`
Return `Result.success({ user: user, access_token: oauth_response.access_token })`.

#### 7c. `app/controllers/auth/sessions_controller.rb`
Update `render_success` to extract `result.data[:user]` and enqueue job:

```ruby
def render_success(data)
  FetchEstablishmentsJob.perform_later(data[:user].id, data[:access_token])
  render json: {
    success: true,
    data: UserSerializer.new(data[:user]).serializable_hash[:data],
    token: JwtEncoder.encode(data[:user].id),
    message: "Authenticated successfully"
  }, status: :created
end
```

Update `spec/requests/auth/sessions_spec.rb` to assert the job is enqueued on success.

---

## Files Summary

### Create
| File | Purpose |
|------|---------|
| `db/migrate/<ts>_create_establishments.rb` | Table migration |
| `spec/factories/establishments.rb` | Factory |
| `spec/models/establishment_spec.rb` | Model spec (written first) |
| `app/models/establishment.rb` | Model implementation |
| `spec/vcr_cassettes/govbr/fetch_establishments_*.yml` | 4 VCR cassettes |
| `spec/services/gov_br/fetch_establishments_spec.rb` | Service spec (written first) |
| `app/gateways/gov_br/contribuintes_client.rb` | HTTP gateway |
| `app/services/gov_br/fetch_establishments.rb` | Service implementation |
| `spec/jobs/fetch_establishments_job_spec.rb` | Job spec (written first) |
| `app/jobs/fetch_establishments_job.rb` | Job implementation |

### Modify
| File | Change |
|------|--------|
| `app/lib/oauth_response.rb` | Expose `access_token` |
| `app/services/auth/sign_in_service.rb` | Return user + access_token in result |
| `app/controllers/auth/sessions_controller.rb` | Enqueue job on success |
| `spec/requests/auth/sessions_spec.rb` | Assert job enqueued |

---

## Verification

```bash
bundle exec rspec spec/models/establishment_spec.rb
bundle exec rspec spec/services/gov_br/fetch_establishments_spec.rb
bundle exec rspec spec/jobs/fetch_establishments_job_spec.rb
bundle exec rspec spec/requests/auth/
```
