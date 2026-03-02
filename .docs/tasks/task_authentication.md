# Authentication

This project is the backend of the system using rails 8, while the front-end will be built with ReactJs

Based on the PRD .docs/PRD.md I want to implement the back-end part of the authentication.
Follow the gov.br documentation https://acesso.gov.br/roteiro-tecnico/iniciarintegracao.html#sequencia-visual-passos-autenticacao

First create the request specs using rswag for it using VCR, WebMock.

The structure will be:
spec/
 └── 
    services /
      └── oauth_service_spec.rb

spec/
 └── cassettes/
      └── govbr/
           └── success.yml
           └── bronze.yml
           └── server_error.yml


## scenarios:
1 - successful login
2 - login with bronze level (failure, silver or gold are requires)
3 - Gov.br down (http 500)

## VCR cassets
spec/cassettes/lib/govbr/success.yml
```
http_interactions:
- request:
    method: post
    uri: https://sso.acesso.gov.br/token
  response:
    status:
      code: 200
    headers:
      Content-Type: application/json
    body:
      string: |
        {
          "access_token": "ACCESS_TOKEN_EXEMPLO",
          "id_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwMCIsIm5hbWUiOiJKb2FvIGRhIFNpbHZhIiwiZW1haWwiOiJqb2FvQGV4YW1wbGUuY29tIiwiY29uZmlhYmlsaWRhIjp7Im5pdmVsIjoicHJhdGEifX0.signature",
          "token_type": "Bearer",
          "expires_in": 3600,
          "scope": "openid email profile govbr_confiabilidades govbr_confiabilidades_idtoken"
        }
recorded_with: VCR 6.2.0
```
spec/cassettes/lib/govbr/bronze.yml
```
http_interactions:
- request:
    method: post
    uri: https://sso.acesso.gov.br/token
  response:
    status:
      code: 200
    headers:
      Content-Type: application/json
    body:
      string: |
        {
          "access_token": "ACCESS_TOKEN_EXEMPLO",
          "id_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI5ODc2NTQzMjEwMCIsIm5hbWUiOiJNYXJpYSBCcm9uemUiLCJlbWFpbCI6Im1hcmlhQGV4YW1wbGUuY29tIiwiY29uZmlhYmlsaWRhIjp7Im5pdmVsIjoiYnJvbnplIn19.signature",
          "token_type": "Bearer",
          "expires_in": 3600,
          "scope": "openid email profile govbr_confiabilidades govbr_confiabilidades_idtoken"
        }
recorded_with: VCR 6.2.0
```
spec/cassettes/lib/govbr/server_error.yml
```
http_interactions:
- request:
    method: post
    uri: https://sso.acesso.gov.br/token
  response:
    status:
      code: 500
    headers:
      Content-Type: application/json
    body:
      string: |
        {
          "error": "server_error",
          "error_description": "Ocorreu um erro inesperado no servidor de autenticação."
        }
recorded_with: VCR 6.2.0
```
The app must use clean architecture/onion-architecture, so we'll have the oauth_service usgin a Gov.br adapter (app/lib/gov_br/oauth.rb) to do the call to the API through dependence injection;
Use HTTparty gem to make http requests.
We'll need a mapper to translate the response from the external API into this app domain: app/lib/oauth_reponse.rb.
All services must return a response object to the controller before returning it to the front-end.
```ruby
# app/lib/response.rb
class Response
  attr_reader :status, :data, :errors, :meta, :http_status

  SUCCESS = :success
  FAILURE = :failure

  def initialize(status:, data: nil, errors: [], meta: {}, http_status: nil)
    @status = status
    @data = data
    @errors = errors
    @meta = meta
    @http_status = http_status
  end

  def self.success(data = nil, meta: {})
    new(status: SUCCESS, data: data, meta: meta, http_status: :ok)
  end

  def self.failure(errors, http_status: :unprocessable_content, meta: {})
    errors = [ errors ] unless errors.is_a?(Array)
    new(status: FAILURE, errors: errors, meta: meta, http_status: http_status)
  end

  def success?
    status == SUCCESS
  end

  def failure?
    status == FAILURE
  end
end
```

# Errors
**InsufficientTrustLevel** when level is bronze
```ruby
level = payload.dig("confiabilidade", "nivel")

raise InsufficientTrustLevel if level == "bronze"
```