# frozen_string_literal: true

class OauthResponse
  VALID_TRUST_LEVELS = %w[prata ouro].freeze

  def initialize(id_token:)
    @payload = decode_payload(id_token)
  end

  def cpf
    @payload["sub"]
  end

  def name
    @payload["name"]
  end

  def email
    @payload["email"]
  end

  def trust_level
    @payload.dig("confiabilidade", "nivel")
  end

  def valid?
    cpf.present? && VALID_TRUST_LEVELS.include?(trust_level)
  end

  private

  def decode_payload(id_token)
    encoded = id_token.split(".")[1]
    padded  = encoded + "=" * ((4 - encoded.length % 4) % 4)
    JSON.parse(Base64.urlsafe_decode64(padded))
  end
end
