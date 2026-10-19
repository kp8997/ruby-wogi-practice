# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::Brands API", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:brand) { create(:brand, name: "Acme Books", state: "active", custom_fields: { "category" => "Books" }) }

  describe "GET /api/v1/admin/brands (ADM-2)" do
    let!(:inactive_brand) { create(:brand, name: "Old Brands", state: "inactive") }

    context "when authenticated as admin" do
      it "returns a paginated list of brands" do
        get "/api/v1/admin/brands", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:brands].length).to be >= 2
        expect(json_response[:pagination][:total_count]).to be >= 2
        expect(json_response[:pagination][:page]).to eq(1)

        first_brand = json_response[:brands].first
        expect(first_brand).to include(:id, :name, :state, :custom_fields)
      end

      it "filters brands by state" do
        get "/api/v1/admin/brands", params: { state: "inactive" }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:brands].all? { |b| b[:state] == "inactive" }).to be true
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/brands", headers: auth_headers(client_user)

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:message]).to eq("Admin access required")
      end
    end

    context "when unauthenticated (AUTH-5)" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/brands"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/admin/brands (ADM-2, LOG-1, LOG-2)" do
    let(:valid_params) do
      {
        name: "Nova Coffee",
        state: "active",
        custom_fields: {
          "category" => "Food & Beverage",
          "website" => "https://novacoffee.com"
        }
      }
    end

    context "when authenticated as admin" do
      it "creates a new brand and returns 201 Created" do
        expect {
          post "/api/v1/admin/brands",
               params: valid_params,
               headers: auth_headers(admin),
               as: :json
        }.to change(Brand, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:brand][:name]).to eq("Nova Coffee")
        expect(json_response[:brand][:state]).to eq("active")
        expect(json_response[:brand][:custom_fields]["category"]).to eq("Food & Beverage")
      end

      it "audits brand.create with after values (LOG-1, LOG-2)" do
        post "/api/v1/admin/brands",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        brand_id = json_response[:brand][:id]
        log = AuditLog.where(action: "brand.create", record_id: brand_id).last

        expect(log).to be_present
        expect(log.user_id).to eq(admin.id)
        expect(log.record_type).to eq("Brand")
        expect(log.after_values["name"]).to eq("Nova Coffee")
      end

      it "returns 422 when brand name is a duplicate (case-insensitive)" do
        post "/api/v1/admin/brands",
             params: valid_params.merge(name: "acme books"),
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:error]).to eq("Validation Error")
        expect(json_response[:details]).to include("Name has already been taken")
      end

      it "returns 422 when custom_fields contains more than 5 fields" do
        large_custom_fields = {
          "f1" => "1", "f2" => "2", "f3" => "3", "f4" => "4", "f5" => "5", "f6" => "6"
        }

        post "/api/v1/admin/brands",
             params: valid_params.merge(custom_fields: large_custom_fields),
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:details].to_s).to include("cannot contain more than 5 custom fields")
      end

      it "returns 422 when custom_fields contains nested objects" do
        nested_fields = { "nested" => { "key" => "value" } }

        post "/api/v1/admin/brands",
             params: valid_params.merge(custom_fields: nested_fields),
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:details].to_s).to include("must be simple scalar types")
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/brands",
             params: valid_params,
             headers: auth_headers(client_user),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/admin/brands/:id (ADM-2)" do
    it "returns the brand details and product count" do
      create(:product, brand: brand)

      get "/api/v1/admin/brands/#{brand.id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:brand][:id]).to eq(brand.id)
      expect(json_response[:brand][:name]).to eq("Acme Books")
      expect(json_response[:brand][:products_count]).to eq(1)
    end

    it "returns 404 when brand is not found" do
      get "/api/v1/admin/brands/999999", headers: auth_headers(admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/admin/brands/:id (ADM-2, LOG-1, LOG-2)" do
    it "updates brand details and records brand.update audit log" do
      patch "/api/v1/admin/brands/#{brand.id}",
            params: { name: "Acme Global Books", custom_fields: { "category" => "Media" } },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:brand][:name]).to eq("Acme Global Books")
      expect(json_response[:brand][:custom_fields]["category"]).to eq("Media")

      log = AuditLog.where(action: "brand.update", record_id: brand.id).last
      expect(log).to be_present
      expect(log.user_id).to eq(admin.id)
      expect(log.before_values["name"]).to eq("Acme Books")
      expect(log.after_values["name"]).to eq("Acme Global Books")
    end
  end

  describe "PATCH /api/v1/admin/brands/:id/state (ADM-4, LOG-1, LOG-2)" do
    it "toggles state between active and inactive with brand.state_change audit log" do
      patch "/api/v1/admin/brands/#{brand.id}/state",
            params: { state: "inactive" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:brand][:state]).to eq("inactive")
      expect(brand.reload.inactive?).to be true

      log = AuditLog.where(action: "brand.state_change", record_id: brand.id).last
      expect(log).to be_present
      expect(log.user_id).to eq(admin.id)
      expect(log.before_values["state"]).to eq("active")
      expect(log.after_values["state"]).to eq("inactive")
    end

    it "reactivates brand" do
      brand.update_column(:state, "inactive")

      patch "/api/v1/admin/brands/#{brand.id}/state",
            params: { state: "active" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(brand.reload.active?).to be true
    end

    it "rejects non-admin users (AUTH-6)" do
      patch "/api/v1/admin/brands/#{brand.id}/state",
            params: { state: "inactive" },
            headers: auth_headers(client_user),
            as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
