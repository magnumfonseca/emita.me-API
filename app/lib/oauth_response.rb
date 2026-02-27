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
    payload, _header = JWT.decode(id_token, nil, false)
    payload
  rescue JWT::DecodeError
    raise Errors::InvalidToken
  end
end
