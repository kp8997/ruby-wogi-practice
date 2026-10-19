# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Client::Products API", type: :request do
  let!(:admin_user) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:client) { create(:client, user: client_user, payout_rate: 6.00) }

  let!(:other_client_user) { create(:user, role: "client") }
  let!(:other_client) { create(:client, user: other_client_user) }

  let!(:brand_a) { create(:brand, name: "Amazon", state: "active") }
  let!(:brand_b) { create(:brand, name: "BestBuy", state: "active") }
  let!(:inactive_brand) { create(:brand, name: "DeadBrand", state: "inactive") }

  let!(:product_1) { create(:product, brand: brand_a, name: "Amazon $50 USD", denomination: 50.00, currency: "USD", state: "active") }
  let!(:product_2) { create(:product, brand: brand_b, name: "BestBuy 100 EUR", denomination: 100.00, currency: "EUR", state: "active") }
  let!(:product_inactive) { create(:product, brand: brand_a, name: "Amazon Promo Inactive", denomination: 10.00, state: "inactive") }
  let!(:product_inactive_brand) { create(:product, brand: inactive_brand, name: "Dead Brand Card", denomination: 25.00, state: "active") }
  let!(:product_unassigned) { create(:product, brand: brand_a, name: "Amazon $500 Unassigned", denomination: 500.00, state: "active") }

  before do
    # Grant client access to product_1, product_2, product_inactive, and product_inactive_brand
    create(:client_product_access, client: client, product: product_1)
    create(:client_product_access, client: client, product: product_2)
    create(:client_product_access, client: client, product: product_inactive)
    create(:client_product_access, client: client, product: product_inactive_brand)

    # Grant other client access to product_unassigned
    create(:client_product_access, client: other_client, product: product_unassigned)
  end

  describe "GET /api/v1/client/products (CLI-2, AUTH-7)" do
    context "when authenticated as client" do
      it "returns only active products assigned to the client with active brands" do
        get "/api/v1/client/products", headers: auth_headers(client_user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:products].length).to eq(2)
        product_ids = json_response[:products].map { |p| p[:id] }
        expect(product_ids).to contain_exactly(product_1.id, product_2.id)
        expect(product_ids).not_to include(product_inactive.id)
        expect(product_ids).not_to include(product_inactive_brand.id)
        expect(product_ids).not_to include(product_unassigned.id)

        first_p = json_response[:products].find { |p| p[:id] == product_1.id }
        expect(first_p).to include(
          id: product_1.id,
          brand_id: brand_a.id,
          brand_name: "Amazon",
          name: "Amazon $50 USD",
          denomination: "50.0",
          currency: "USD",
          requires_pin: false
        )
      end

      it "filters catalog by search query (brand or product name)" do
        get "/api/v1/client/products", params: { query: "bestbuy" }, headers: auth_headers(client_user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:products].length).to eq(1)
        expect(json_response[:products].first[:id]).to eq(product_2.id)
      end

      it "filters catalog by currency" do
        get "/api/v1/client/products", params: { currency: "USD" }, headers: auth_headers(client_user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:products].length).to eq(1)
        expect(json_response[:products].first[:id]).to eq(product_1.id)
      end

      it "paginates catalog results" do
        get "/api/v1/client/products", params: { page: 1, per_page: 1 }, headers: auth_headers(client_user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:products].length).to eq(1)
        expect(json_response[:pagination][:total_count]).to eq(2)
        expect(json_response[:pagination][:total_pages]).to eq(2)
        expect(json_response[:pagination][:page]).to eq(1)
      end
    end

    context "role authorization and security checks" do
      it "returns 403 Forbidden for admin users (AUTH-6)" do
        get "/api/v1/client/products", headers: auth_headers(admin_user)

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:message]).to eq("Client access required")
      end

      it "returns 401 Unauthorized for unauthenticated requests (AUTH-5)" do
        get "/api/v1/client/products"

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 Unauthorized for deactivated client user (AUTH-8)" do
        client_user.update!(state: "inactive")
        get "/api/v1/client/products", headers: auth_headers(client_user)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
