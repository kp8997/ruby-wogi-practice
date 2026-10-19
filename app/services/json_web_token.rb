# frozen_string_literal: true

class JsonWebToken
  SECRET_KEY = ENV.fetch("JWT_SECRET_KEY") { Rails.application.secret_key_base }

  def self.encode(payload, exp = 1.hour.from_now)
    payload_to_encode = payload.dup
    payload_to_encode[:jti] = SecureRandom.uuid
    payload_to_encode[:exp] = exp.to_i
    JWT.encode(payload_to_encode, SECRET_KEY, "HS256")
  end

  def self.decode(token)
    return nil if token.blank?

    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: "HS256" })[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
