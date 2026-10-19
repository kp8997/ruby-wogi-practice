# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::Products API", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:client_profile) { create(:client, user: client_user) }
  let!(:brand) { create(:brand, name: "Acme Brand") }
  let!(:product) { create(:product, brand: brand, name: "Acme $25 Gift", denomination: 25.0, currency: "USD") }

  describe "POST /api/v1/admin/brands/:id/products (ADM-3, LOG-1, LOG-2)" do
    let(:valid_params) do
      {
        name: "Acme $50 Card",
        denomination: 50.0,
        currency: "USD",
        requires_pin: true,
        state: "active",
        custom_fields: { "sku" => "ACME-50" }
      }
    end

    context "when authenticated as admin" do
      it "creates a new product under the brand and returns 201 Created" do
        expect {
          post "/api/v1/admin/brands/#{brand.id}/products",
               params: valid_params,
               headers: auth_headers(admin),
               as: :json
        }.to change(Product, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:product][:name]).to eq("Acme $50 Card")
        expect(json_response[:product][:denomination].to_f).to eq(50.0)
        expect(json_response[:product][:currency]).to eq("USD")
        expect(json_response[:product][:requires_pin]).to be true
        expect(json_response[:product][:brand_id]).to eq(brand.id)
      end

      it "audits product.create with after values (LOG-1, LOG-2)" do
        post "/api/v1/admin/brands/#{brand.id}/products",
             params: valid_params,
             headers: auth_headers(admin),
             as: :json

        prod_id = json_response[:product][:id]
        log = AuditLog.where(action: "product.create", record_id: prod_id).last

        expect(log).to be_present
        expect(log.user_id).to eq(admin.id)
        expect(log.record_type).to eq("Product")
        expect(log.after_values["name"]).to eq("Acme $50 Card")
      end

      it "returns 422 when product name is a duplicate under the same brand" do
        post "/api/v1/admin/brands/#{brand.id}/products",
             params: valid_params.merge(name: "Acme $25 Gift"),
             headers: auth_headers(admin),
             as: :json

        expect(response).to have_http_status(422)
        expect(json_response[:error]).to eq("Validation Error")
        expect(json_response[:details]).to include("Name has already been taken")
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/brands/#{brand.id}/products",
             params: valid_params,
             headers: auth_headers(client_user),
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/admin/brands/:id/products (ADM-3)" do
    let!(:inactive_product) { create(:product, brand: brand, name: "Old Inactive Card", state: "inactive") }

    it "returns paginated products for the brand" do
      get "/api/v1/admin/brands/#{brand.id}/products", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:products].length).to be >= 2
      expect(json_response[:pagination][:total_count]).to be >= 2
    end

    it "filters products by state" do
      get "/api/v1/admin/brands/#{brand.id}/products", params: { state: "inactive" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:products].all? { |p| p[:state] == "inactive" }).to be true
    end
  end

  describe "GET /api/v1/admin/products/:id (ADM-3)" do
    it "returns single product details" do
      get "/api/v1/admin/products/#{product.id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response[:product][:id]).to eq(product.id)
      expect(json_response[:product][:name]).to eq(product.name)
      expect(json_response[:product][:brand_name]).to eq(brand.name)
    end

    it "returns 404 when product is not found" do
      get "/api/v1/admin/products/999999", headers: auth_headers(admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/admin/products/:id (ADM-3, LOG-1, LOG-2)" do
    it "updates product details and records product.update audit log" do
      patch "/api/v1/admin/products/#{product.id}",
            params: { name: "Updated $25 Card", denomination: 30.0 },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:product][:name]).to eq("Updated $25 Card")
      expect(json_response[:product][:denomination].to_f).to eq(30.0)

      log = AuditLog.where(action: "product.update", record_id: product.id).last
      expect(log).to be_present
      expect(log.user_id).to eq(admin.id)
      expect(log.before_values["name"]).to eq("Acme $25 Gift")
      expect(log.after_values["name"]).to eq("Updated $25 Card")
    end
  end

  describe "PATCH /api/v1/admin/products/:id/state (ADM-4, LOG-1, LOG-2)" do
    it "toggles state between active and inactive with product.state_change audit log" do
      patch "/api/v1/admin/products/#{product.id}/state",
            params: { state: "inactive" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:product][:state]).to eq("inactive")
      expect(product.reload.inactive?).to be true

      log = AuditLog.where(action: "product.state_change", record_id: product.id).last
      expect(log).to be_present
      expect(log.user_id).to eq(admin.id)
      expect(log.before_values["state"]).to eq("active")
      expect(log.after_values["state"]).to eq("inactive")
    end
  end

  describe "DELETE /api/v1/admin/products/:id (ADM-3, LOG-1, LOG-2)" do
    context "when no cards have been issued" do
      it "soft deletes the product and records product.delete audit log" do
        delete "/api/v1/admin/products/#{product.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Product deleted successfully")
        expect(product.reload.discarded?).to be true

        log = AuditLog.where(action: "product.delete", record_id: product.id).last
        expect(log).to be_present
        expect(log.user_id).to eq(admin.id)
        expect(log.after_values["deleted_at"]).to be_present
      end
    end

    context "when cards have already been issued for this product" do
      it "returns 409 Conflict and rejects deletion" do
        create(:card, product: product, client: client_profile)

        delete "/api/v1/admin/products/#{product.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:conflict)
        expect(json_response[:message]).to include("Cannot delete product with existing issued cards")
        expect(product.reload.discarded?).to be false
      end
    end
  end

  describe "Client Product Accesses (ADM-6, LOG-1, LOG-2)" do
    describe "POST /api/v1/admin/clients/:id/product_accesses" do
      it "grants product access to client and records audit log" do
        expect {
          post "/api/v1/admin/clients/#{client_profile.id}/product_accesses",
               params: { product_id: product.id },
               headers: auth_headers(admin),
               as: :json
        }.to change(ClientProductAccess, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:product_access][:client_id]).to eq(client_profile.id)
        expect(json_response[:product_access][:product_id]).to eq(product.id)

        log = AuditLog.where(action: "client_product_access.create").last
        expect(log).to be_present
        expect(log.user_id).to eq(admin.id)
        expect(log.metadata["client_id"]).to eq(client_profile.id)
        expect(log.metadata["product_id"]).to eq(product.id)
      end

      it "is idempotent when access has already been granted" do
        create(:client_product_access, client: client_profile, product: product)

        expect {
          post "/api/v1/admin/clients/#{client_profile.id}/product_accesses",
               params: { product_id: product.id },
               headers: auth_headers(admin),
               as: :json
        }.not_to change(ClientProductAccess, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /api/v1/admin/clients/:id/product_accesses" do
      it "lists accessible products for the client" do
        create(:client_product_access, client: client_profile, product: product)

        get "/api/v1/admin/clients/#{client_profile.id}/product_accesses", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:product_accesses].length).to eq(1)
        expect(json_response[:product_accesses].first[:product_id]).to eq(product.id)
      end
    end

    describe "DELETE /api/v1/admin/clients/:id/product_accesses/:product_id" do
      it "revokes product access from client and records audit log" do
        create(:client_product_access, client: client_profile, product: product)

        expect {
          delete "/api/v1/admin/clients/#{client_profile.id}/product_accesses/#{product.id}",
                 headers: auth_headers(admin)
        }.to change(ClientProductAccess, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Product access revoked successfully")

        log = AuditLog.where(action: "client_product_access.delete").last
        expect(log).to be_present
        expect(log.user_id).to eq(admin.id)
      end
    end
  end
end
