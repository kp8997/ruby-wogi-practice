# frozen_string_literal: true

module V1
  module Helpers
    module AuthHelpers
      def current_user
        return @current_user if defined?(@current_user)

        auth_header = headers["Authorization"]
        return nil if auth_header.blank?

        token = auth_header.split(" ").last
        payload = JsonWebToken.decode(token)
        return nil unless payload
        return nil if RevokedToken.revoked?(payload[:jti])

        user = User.find_by(id: payload[:user_id])
        return nil unless user&.state_active?

        @raw_token = token
        @token_payload = payload
        @current_user = user
      end

      # This error will be handled by grape that return a json with {error, message}
      # And this error will not be caught by rescue_from
      def authenticate!
        error!({ error: "Unauthorized", message: "Invalid or expired token" }, 401) unless current_user
      end

      def current_token_payload
        @token_payload
      end
    end
  end
end
