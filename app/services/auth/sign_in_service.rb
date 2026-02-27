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
        u.name        = oauth_response.name
        u.email       = oauth_response.email
        u.trust_level = oauth_response.trust_level
      end.tap { |u| u.update!(trust_level: oauth_response.trust_level) }
    end
  end
end
