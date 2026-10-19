# frozen_string_literal: true

module V1
  class Auth < Grape::API
    resource :auth do
      desc "User login endpoint"
      params do
        requires :email, type: String, regexp: URI::MailTo::EMAIL_REGEXP, desc: "User email"
        requires :password, type: String, desc: "User password"
      end
      post :login do
        status 200
        user = User.find_by("lower(email) = ?", params[:email].strip.downcase)

        if user&.authenticate(params[:password])
          unless user.state_active?
            ::Audit::Recorder.record!(
              action: "auth.login_failed",
              metadata: { email: params[:email], reason: "account_inactive" }
            )
            error!({ error: "Forbidden", message: "Account is inactive" }, 403)
          end

          Current.user = user
          user.update_column(:last_login_at, Time.current)

          ::Audit::Recorder.record!(
            action: "auth.login",
            record: user
          )

          token = JsonWebToken.encode(user_id: user.id, role: user.role)

          {
            token: token,
            user: {
              id: user.id,
              email: user.email,
              role: user.role
            }
          }
        else
          ::Audit::Recorder.record!(
            action: "auth.login_failed",
            metadata: { email: params[:email], reason: "invalid_credentials" }
          )
          error!({ error: "Unauthorized", message: "Invalid email or password" }, 401)
        end
      end

      desc "User logout endpoint"
      delete :logout do
        authenticate!

        RevokedToken.create!(
          user: current_user,
          jti: current_token_payload[:jti],
          expires_at: Time.at(current_token_payload[:exp])
        )

        ::Audit::Recorder.record!(
          action: "auth.logout",
          record: current_user
        )

        { message: "Logged out successfully" }
      end
    end
  end
end
