require 'rails_helper'

RSpec.describe "V1::Auth API", type: :request do
  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "user@example.com", password: "Password@123", role: "client") }

    context "with valid credentials" do
      it "returns 200 and a valid JWT token" do
        post "/api/v1/auth/login",
             params: { email: "User@example.com", password: "Password@123" },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:token]).to be_present
        expect(json_response[:user][:email]).to eq("user@example.com")
        expect(json_response[:user][:role]).to eq("client")
      end

      it "creates an auth.login audit log" do
        expect {
          post "/api/v1/auth/login",
               params: { email: user.email, password: "Password@123" },
               as: :json
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("auth.login")
        expect(log.user_id).to eq(user.id)
      end

      it "updates user last_login_at" do
        expect {
          post "/api/v1/auth/login",
               params: { email: user.email, password: "Password@123" },
               as: :json
        }.to change { user.reload.last_login_at }.from(nil)
      end
    end

    context "with invalid password" do
      it "returns 401 Unauthorized" do
        post "/api/v1/auth/login",
             params: { email: user.email, password: "WrongPassword" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq("Unauthorized")
      end

      it "records auth.login_failed without logging the password" do
        post "/api/v1/auth/login",
             params: { email: user.email, password: "SuperSecretPassword" },
             as: :json

        log = AuditLog.last
        expect(log.action).to eq("auth.login_failed")
        expect(log.metadata["reason"]).to eq("invalid_credentials")
        expect(log.metadata["email"]).to eq(user.email)
        expect(log.metadata.to_s).not_to include("SuperSecretPassword")
      end
    end

    context "with deactivated account (AUTH-8)" do
      let!(:inactive_user) { create(:user, :inactive, password: "Password@123") }

      it "returns 403 Forbidden" do
        post "/api/v1/auth/login",
             params: { email: inactive_user.email, password: "Password@123" },
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:message]).to eq("Account is inactive")
      end

      it "records auth.login_failed with account_inactive reason" do
        post "/api/v1/auth/login",
             params: { email: inactive_user.email, password: "Password@123" },
             as: :json

        log = AuditLog.last
        expect(log.action).to eq("auth.login_failed")
        expect(log.metadata["reason"]).to eq("account_inactive")
      end
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    let!(:user) { create(:user) }

    context "without authentication token" do
      it "returns 401 Unauthorized" do
        delete "/api/v1/auth/logout"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with valid token" do
      it "revokes the token and logs out successfully" do
        headers = auth_headers(user)

        delete "/api/v1/auth/logout", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Logged out successfully")
        expect(RevokedToken.count).to eq(1)

        # Re-using the token must now be rejected
        delete "/api/v1/auth/logout", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "records an auth.logout audit log" do
        headers = auth_headers(user)

        expect {
          delete "/api/v1/auth/logout", headers: headers
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("auth.logout")
        expect(log.user_id).to eq(user.id)
      end
    end
  end
end
