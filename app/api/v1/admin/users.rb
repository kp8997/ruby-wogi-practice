# frozen_string_literal: true

module V1
  module Admin
    class Users < Grape::API
      resource :admin do
        resource :users do
          desc "Create a new admin user (AUTH-3)"
          params do
            requires :email, type: String, regexp: URI::MailTo::EMAIL_REGEXP, desc: "Admin email"
            requires :password, type: String, desc: "Admin password"
          end
          post do
            authorize_admin!

            user = User.new(
              email: params[:email],
              password: params[:password],
              role: "admin",
              state: "active"
            )

            if user.save
              ::Audit::Recorder.record!(
                action: "user.create",
                record: user,
                after: { id: user.id, email: user.email, role: user.role, state: user.state },
                metadata: { role: "admin", email: user.email }
              )

              status 201
              {
                user: {
                  id: user.id,
                  email: user.email,
                  role: user.role,
                  state: user.state,
                  created_at: user.created_at
                }
              }
            else
              error!({ error: "Validation Error", details: user.errors.full_messages }, 422)
            end
          end
        end
      end
    end
  end
end
