# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::Clients API", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:client_profile) { create(:client, user: client_user, name: "Initial Store", payout_rate: 5.0) }

  describe "GET /api/v1/admin/clients" do
    let!(:inactive_user) { create(:user, :inactive) }
    let!(:inactive_client) { create(:client, user: inactive_user, name: "Inactive Store", payout_rate: 10.0) }

    context "when authenticated as admin" do
      it "returns a paginated list of clients" do
        get "/api/v1/admin/clients", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:clients].length).to be >= 2
        expect(json_response[:pagination][:total_count]).to be >= 2
        expect(json_response[:pagination][:page]).to eq(1)
        expect(json_response[:pagination][:per_page]).to eq(20)

        first_client = json_response[:clients].first
        expect(first_client).to include(:id, :name, :payout_rate, :user)
        expect(first_client[:user]).to include(:id, :email, :role, :state)
      end

      it "filters clients by user state" do
        get "/api/v1/admin/clients", params: { state: "inactive" }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:clients].all? { |c| c[:user][:state] == "inactive" }).to be true
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/clients", headers: auth_headers(client_user)

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:message]).to eq("Admin access required")
      end
    end

    context "when unauthenticated (AUTH-5)" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/clients"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/admin/clients" do
    let(:valid_params) do
      {
        name: "Acme Retailers",
        email: "acme_new@example.com",
        password: "ClientPassword@123",
        payout_rate: 7.50
      }
    end

    context "when authenticated as admin" do
      it "creates a new user and client profile (AUTH-4, ADM-5)" do
        expect {
          post "/api/v1/admin/clients",
               params: valid_params,
               headers: auth_headers(admin),
               as: :json
        }.to change(Client, :count).by(1).and change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:client][:name]).to eq("Acme Retailers")
        expect(json_response[:client][:payout_rate].to_f).to eq(7.50)
        expect(json_response[:client][:user][:email]).to eq("acme_new@example.com")
        expect(json_response[:client][:user][:role]).to eq("client")
        expect(json_response[:client][:user][:state]).to eq("active")
      end

      it "audits the client and user creation without logging passwords (LOG-1, LOG-6)" do
        post "/api/v1/admin/clients",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        user_log = AuditLog.find_by(action: "user.create")
        expect(user_log).to be_present
        expect(user_log.user_id).to eq(admin.id)
        expect(user_log.metadata["role"]).to eq("client")
        expect(user_log.metadata.to_s).not_to include("ClientPassword@123")
        expect(user_log.after_values.to_s).not_to include("ClientPassword@123")

        client_log = AuditLog.where(action: "client.create").order(:id).last
        expect(client_log).to be_present
        expect(client_log.user_id).to eq(admin.id)
        expect(client_log.record_type).to eq("Client")
        expect(client_log.record_id).to eq(json_response[:client][:id])
      end

      it "returns 422 if email is already taken" do
        create(:user, email: "acme_new@example.com")

        post "/api/v1/admin/clients",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:error]).to eq("Validation Error")
        expect(json_response[:details]).to include("Email has already been taken")
      end

      it "returns 400 or 422 when payout rate is out of bounds (0..100)" do
        post "/api/v1/admin/clients",
             params: valid_params.merge(payout_rate: 150.0),
             headers: auth_headers(admin),
             as: :json

        expect([400, 422]).to include(response.status)
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/clients",
             params: valid_params,
             headers: auth_headers(client_user),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/admin/clients/:id" do
    it "returns single client details" do
      get "/api/v1/admin/clients/#{client_profile.id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:client][:id]).to eq(client_profile.id)
      expect(json_response[:client][:name]).to eq(client_profile.name)
      expect(json_response[:client][:user][:id]).to eq(client_user.id)
    end

    it "returns 404 when client is not found" do
      get "/api/v1/admin/clients/999999", headers: auth_headers(admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/admin/clients/:id" do
    it "updates client name and payout_rate with audit diff (LOG-2)" do
      expect {
        patch "/api/v1/admin/clients/#{client_profile.id}",
              params: { name: "Updated Retail Name", payout_rate: 8.25 },
              headers: auth_headers(admin),
              as: :json
      }.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response[:client][:name]).to eq("Updated Retail Name")
      expect(json_response[:client][:payout_rate].to_f).to eq(8.25)

      log = AuditLog.last
      expect(log.action).to eq("client.update")
      expect(log.before_values["name"]).to eq("Initial Store")
      expect(log.after_values["name"]).to eq("Updated Retail Name")
    end
  end

  describe "PATCH /api/v1/admin/clients/:id/state" do
    it "deactivates client account and revokes active API access (ADM-9, AUTH-8)" do
      patch "/api/v1/admin/clients/#{client_profile.id}/state",
            params: { state: "inactive" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:client][:user][:state]).to eq("inactive")
      expect(client_user.reload.state_inactive?).to be true

      log = AuditLog.last
      expect(log.action).to eq("user.state_change")
      expect(log.before_values["state"]).to eq("active")
      expect(log.after_values["state"]).to eq("inactive")

      # AUTH-8: Deactivated client token must now be rejected
      get "/api/v1/admin/clients/#{client_profile.id}", headers: auth_headers(client_user)
      expect(response).to have_http_status(:unauthorized)
    end

    it "reactivates client account" do
      client_user.update_column(:state, "inactive")

      patch "/api/v1/admin/clients/#{client_profile.id}/state",
            params: { state: "active" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(client_user.reload.state_active?).to be true
    end
  end
end
