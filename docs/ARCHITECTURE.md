# Clean Architecture With Rails

## Layer Diagram

```
[HTTP / Web]
     │
     ▼
Controller          (Interface Adapter)
     │
     ├──► Service   (Use Case)
     │         │
     │         ├──► Model / Entity       (persistence-backed domain object)
     │         ├──► lib/ Value Object    (non-persistent domain object)
     │         └──► Gateway             (Interface Adapter → 3rd-party system)
     │
     └──► Serializer / Presenter        (Interface Adapter → JSON output)
```

## Dependency Rule

Dependencies only point **inward**:

- Controllers depend on Services.
- Services depend on Entities and Gateway interfaces.
- Entities depend on nothing outside themselves.
- Gateways implement interfaces defined by the Service layer — Services never depend on a concrete Gateway implementation.

This means the core business logic (Services + Entities) has zero knowledge of Rails, HTTP, or any external system.

---

## Directory Reference

| Path | Layer | Purpose | Example |
|---|---|---|---|
| `app/controllers/` | Interface Adapter | HTTP routing, auth, param handling, render | `Auth::SessionsController` |
| `app/services/` | Use Case | Business workflows, multi-model coordination | `Auth::SignInService` |
| `app/models/` | Entity | ActiveRecord domain objects with persistence | `User`, `Session` |
| `app/gateways/` | Interface Adapter | 3rd-party API adapters with internal mappers | `GovBr::OauthGateway` |
| `app/serializers/` | Interface Adapter | JSON output formatting via JSONAPI::Serializer | `UserSerializer` |
| `app/lib/` | Entity / Value Object | Pure Ruby objects with no persistence | `OauthResponse`, `Result` |

---

## Controller

Controllers belong to the **Interface Adapters** layer. They adapt HTTP requests into calls to the application core and HTTP responses from its output.

Responsibilities:
- Parse and permit params
- Authenticate / authorize the request
- Delegate to a single Service
- Render via a Serializer or return a status

Controllers must not contain business logic. The rule is: **one Service call per action**.

```ruby
module Auth
  class SessionsController < ApplicationController
    def create
      result = Auth::SignInService.new(code: params[:code]).call
      if result.success?
        render json: UserSerializer.new(result.data).serializable_hash, status: :created
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end
  end
end
```

---

## Use Cases (Services)

Services live in `app/services/` and encapsulate business logic unique to the application.

Use a Service when:
- Multiple models are coordinated
- A workflow spans more than one domain concern
- External systems (gateways) need to be called
- The logic doesn't belong to any single model

Services always use keyword arguments and return a `Result` object (see below). They never render, raise for control flow, or reference `params` directly.

```ruby
module Auth
  class SignInService
    def initialize(code:, gateway: GovBr::OauthGateway.new)
      @code    = code
      @gateway = gateway
    end

    def call
      oauth_response = @gateway.fetch_token(code: @code)
      return Result.failure("OAuth failed") unless oauth_response.valid?

      user = find_or_create_user(oauth_response)
      Result.success(user)
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

---

## Entities

Entities encapsulate data and essential domain behavior. They have no knowledge of HTTP, presentation, or external services.

**Persistent entities** → `app/models/` (ActiveRecord)

Keep models focused on data, associations, validations, and domain methods. Delegate complex workflows to Services.

```ruby
class User < ApplicationRecord
  validates :cpf, presence: true, uniqueness: true

  def display_name
    name.presence || email
  end
end
```

**Non-persistent value objects** → `app/lib/`

Use plain Ruby objects when no database persistence is needed.

```ruby
# app/lib/oauth_response.rb
class OauthResponse
  attr_reader :cpf, :name, :email, :trust_level

  def initialize(raw:)
    decoded    = JWT.decode(raw[:id_token], nil, false).first
    @cpf        = decoded["cpf"]
    @name       = decoded["name"]
    @email      = decoded["email"]
    @trust_level = raw[:trust_level]
  end

  def valid?
    cpf.present? && trust_level.to_i >= 2
  end
end
```

---

## Result Object

All Services return a `Result` to communicate success or failure without raising exceptions for control flow.

```ruby
# app/lib/result.rb
class Result
  attr_reader :data, :error

  def self.success(data = nil)
    new(success: true, data: data)
  end

  def self.failure(error)
    new(success: false, error: error)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  private

  def initialize(success:, data: nil, error: nil)
    @success = success
    @data    = data
    @error   = error
  end
end
```

Controllers always branch on `result.success?` and never rescue from Services.

---

## Gateways

Gateways belong to the **Interface Adapters** layer. They isolate the application core from 3rd-party systems by translating external data structures into internal value objects.

A Service depends on the gateway's interface (duck type), not the concrete implementation. This makes the gateway injectable and testable.

**Call chain:**

```
Service
  └── Gateway#call          → HTTP request to external API
        └── ValueObject.new → maps raw response to internal structure
              └── Result    → returned to the Service
```

**Example — Gov.br OAuth:**

```ruby
# app/gateways/gov_br/oauth_gateway.rb
module GovBr
  class OauthGateway
    TOKEN_URL = "https://sso.acesso.gov.br/token".freeze

    def fetch_token(code:)
      raw = HTTParty.post(TOKEN_URL, body: token_params(code))
      OauthResponse.new(raw: raw.parsed_response.symbolize_keys)
    end

    private

    def token_params(code)
      {
        grant_type:   "authorization_code",
        code:         code,
        redirect_uri: ENV.fetch("GOV_BR_REDIRECT_URI"),
        client_id:    ENV.fetch("GOV_BR_CLIENT_ID"),
        client_secret: ENV.fetch("GOV_BR_CLIENT_SECRET")
      }
    end
  end
end
```

Inject the gateway into the Service so tests can substitute a double:

```ruby
# In tests
gateway = instance_double(GovBr::OauthGateway, fetch_token: fake_oauth_response)
Auth::SignInService.new(code: "abc", gateway: gateway).call
```

---

## Presenters (Serializers)

Serializers belong to the **Interface Adapters** layer and are responsible for shaping domain data into the JSON structure consumed by clients. This application uses `JSONAPI::Serializer`.

The Controller is solely responsible for calling the Serializer — Services never serialize.

**Full call chain:**

```
Controller
  └── Service#call → Result
        └── result.data (Entity / model)
              └── Serializer.new(result.data).serializable_hash
                    └── render json: ...
```

```ruby
# app/serializers/user_serializer.rb
class UserSerializer
  include JSONAPI::Serializer

  attributes :name, :email, :cpf
end
```

```ruby
# In the controller
render json: UserSerializer.new(result.data).serializable_hash, status: :ok
```
