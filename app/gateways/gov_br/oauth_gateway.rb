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
