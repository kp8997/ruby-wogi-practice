# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::AuditLogs API", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }

  let!(:log_login) do
    create(:audit_log,
           user: admin,
           action: "auth.login",
           record_type: "User",
           record_id: admin.id,
           created_at: 3.days.ago)
  end

  let!(:log_brand) do
    create(:audit_log,
           user: admin,
           action: "brand.create",
           record_type: "Brand",
           record_id: 10,
           created_at: 2.days.ago)
  end

  let!(:log_card) do
    create(:audit_log,
           user: client_user,
           action: "card.issue",
           record_type: "Card",
           record_id: 20,
           created_at: 1.day.ago)
  end

  describe "GET /api/v1/admin/audit_logs (ADM-7, LOG-5, LOG-6)" do
    context "when authenticated as admin" do
      it "returns a paginated list of audit logs ordered by newest first" do
        get "/api/v1/admin/audit_logs", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:audit_logs].length).to be >= 3
        expect(json_response[:pagination][:total_count]).to be >= 3

        first_log = json_response[:audit_logs].first
        expect(first_log).to include(:id, :action, :user, :record_type, :record_id, :created_at)
      end

      it "filters logs by action" do
        get "/api/v1/admin/audit_logs", params: { action: "brand.create" }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:audit_logs].all? { |l| l[:action] == "brand.create" }).to be true
      end

      it "filters logs by user_id" do
        get "/api/v1/admin/audit_logs", params: { user_id: client_user.id }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:audit_logs].all? { |l| l[:user][:id] == client_user.id }).to be true
      end

      it "filters logs by record_type and record_id" do
        get "/api/v1/admin/audit_logs", params: { record_type: "Card", record_id: 20 }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:audit_logs].length).to eq(1)
        expect(json_response[:audit_logs].first[:record_type]).to eq("Card")
        expect(json_response[:audit_logs].first[:record_id]).to eq(20)
      end

      it "filters logs within date range" do
        from = 2.days.ago.to_date.to_s
        to = Time.current.to_date.to_s

        get "/api/v1/admin/audit_logs", params: { from_date: from, to_date: to }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        actions = json_response[:audit_logs].map { |l| l[:action] }
        expect(actions).to include("brand.create", "card.issue")
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/audit_logs", headers: auth_headers(client_user)

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:message]).to eq("Admin access required")
      end
    end

    context "when unauthenticated (AUTH-5)" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/audit_logs"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
