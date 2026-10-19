# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::Users API", type: :request do
  describe "POST /api/v1/admin/users" do
    let!(:admin) { create(:user, :admin) }
    let!(:client_user) { create(:user, role: "client") }

    let(:valid_params) do
      {
        email: "new_admin@example.com",
        password: "SecurePassword@123"
      }
    end

    context "when authenticated as an admin (AUTH-3)" do
      it "creates a new admin user and returns 201 Created" do
        post "/api/v1/admin/users",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(:created)
        expect(json_response[:user][:email]).to eq("new_admin@example.com")
        expect(json_response[:user][:role]).to eq("admin")
        expect(json_response[:user][:state]).to eq("active")

        created_user = User.find_by(email: "new_admin@example.com")
        expect(created_user).to be_present
        expect(created_user.role_admin?).to be true
      end

      it "records an audit log for user.create (LOG-1, LOG-6)" do
        expect {
          post "/api/v1/admin/users",
               params: valid_params,
               headers: auth_headers(admin),
               as: :json
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("user.create")
        expect(log.user_id).to eq(admin.id)
        expect(log.record_type).to eq("User")
        expect(log.metadata["role"]).to eq("admin")
        expect(log.metadata["email"]).to eq("new_admin@example.com")

        # LOG-6: Passwords must NEVER appear in audit log
        expect(log.after_values.to_s).not_to include("SecurePassword@123")
        expect(log.metadata.to_s).not_to include("SecurePassword@123")
      end

      it "returns 422 Unprocessable Entity when email is already taken" do
        create(:user, email: "new_admin@example.com")

        post "/api/v1/admin/users",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:error]).to eq("Validation Error")
        expect(json_response[:details]).to include("Email has already been taken")
      end

      it "returns 422 Unprocessable Entity when password is too short" do
        post "/api/v1/admin/users",
             params: valid_params.merge(password: "short"),
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:error]).to eq("Validation Error")
        expect(json_response[:details]).to include("Password is too short (minimum is 8 characters)")
      end
    end

    context "when authenticated as a client user (AUTH-6)" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/users",
             params: valid_params,
             headers: auth_headers(client_user),
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("Forbidden")
        expect(json_response[:message]).to eq("Admin access required")
      end
    end

    context "when unauthenticated (AUTH-5)" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/users",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq("Unauthorized")
        expect(json_response[:message]).to eq("Invalid or expired token")
      end
    end
  end
end
