# frozen_string_literal: true

class JwtEncoder
  ALGORITHM = "HS256"
  EXPIRY    = 24.hours

  def self.encode(user_id)
    now = Time.current.to_i
    payload = { user_id: user_id, iat: now, exp: now + EXPIRY.to_i }
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError
    nil
  end

  private_class_method def self.secret
    ENV.fetch("JWT_SECRET") { raise "JWT_SECRET environment variable is required" }
  end
end
