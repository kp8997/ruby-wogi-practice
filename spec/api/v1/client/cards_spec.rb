# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Client::Cards API", type: :request do
  let!(:admin_user) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:client) { create(:client, user: client_user, payout_rate: 8.50) }

  let!(:other_client_user) { create(:user, role: "client") }
  let!(:other_client) { create(:client, user: other_client_user, payout_rate: 5.00) }

  let!(:brand) { create(:brand, name: "Target Retail", state: "active") }
  let!(:inactive_brand) { create(:brand, name: "Closed Retail", state: "inactive") }

  let!(:product) { create(:product, brand: brand, name: "Target $100 Card", denomination: 100.00, currency: "USD", state: "active", requires_pin: true) }
  let!(:product_no_pin) { create(:product, brand: brand, name: "Target $25 Digital", denomination: 25.00, currency: "USD", state: "active", requires_pin: false) }
  let!(:product_inactive) { create(:product, brand: brand, name: "Old Promo", denomination: 10.00, currency: "USD", state: "inactive") }
  let!(:product_inactive_brand) { create(:product, brand: inactive_brand, name: "Closed Brand Card", denomination: 50.00, currency: "USD", state: "active") }
  let!(:unassigned_product) { create(:product, brand: brand, name: "Target $500 VIP", denomination: 500.00, currency: "USD", state: "active") }

  before do
    # Grant client access
    create(:client_product_access, client: client, product: product)
    create(:client_product_access, client: client, product: product_no_pin)
    create(:client_product_access, client: client, product: product_inactive)
    create(:client_product_access, client: client, product: product_inactive_brand)

    # Grant other client access to unassigned_product
    create(:client_product_access, client: other_client, product: unassigned_product)
  end

  describe "GET /api/v1/client/cards (CLI-1, AUTH-7)" do
    let!(:card1) { create(:card, client: client, product: product, status: "issued", pin: "1234", amount: 100.00) }
    let!(:card2) { create(:card, :cancelled, client: client, product: product_no_pin, pin: nil, amount: 25.00) }
    let!(:other_card) { create(:card, client: other_client, product: unassigned_product, amount: 500.00) }

    it "retrieves paginated list of cards owned by the client without PIN (AUTH-7, LOG-6)" do
      get "/api/v1/client/cards", headers: auth_headers(client_user)

      expect(response).to have_http_status(:ok)
      expect(json_response[:cards].length).to eq(2)
      card_ids = json_response[:cards].map { |c| c[:id] }
      expect(card_ids).to contain_exactly(card1.id, card2.id)
      expect(card_ids).not_to include(other_card.id)

      # Check pagination
      expect(json_response[:pagination][:total_count]).to eq(2)
      expect(json_response[:pagination][:page]).to eq(1)

      # Check card fields (PIN is omitted)
      first_card = json_response[:cards].find { |c| c[:id] == card1.id }
      expect(first_card).to include(
        id: card1.id,
        product_id: product.id,
        product_name: "Target $100 Card",
        brand_name: "Target Retail",
        activation_number: card1.activation_number,
        amount: "100.0",
        currency: "USD",
        status: "issued"
      )
      expect(first_card).not_to have_key(:pin)
    end

    it "filters cards by status" do
      get "/api/v1/client/cards", params: { status: "cancelled" }, headers: auth_headers(client_user)

      expect(response).to have_http_status(:ok)
      expect(json_response[:cards].length).to eq(1)
      expect(json_response[:cards].first[:id]).to eq(card2.id)
    end
  end

  describe "GET /api/v1/client/cards/:id (CLI-1, AUTH-7)" do
    let!(:card) { create(:card, client: client, product: product, pin: "4321") }
    let!(:other_card) { create(:card, client: other_client, product: unassigned_product) }

    it "retrieves single card details without PIN" do
      get "/api/v1/client/cards/#{card.id}", headers: auth_headers(client_user)

      expect(response).to have_http_status(:ok)
      expect(json_response[:card][:id]).to eq(card.id)
      expect(json_response[:card][:activation_number]).to eq(card.activation_number)
      expect(json_response[:card]).not_to have_key(:pin)
    end

    it "returns 404 Not Found when attempting to access another client's card (AUTH-7)" do
      get "/api/v1/client/cards/#{other_card.id}", headers: auth_headers(client_user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/client/cards (CLI-3, CLI-4, CLI-5, LOG-4, LOG-6)" do
    let(:idempotency_key) { "tx-client-test-#{SecureRandom.hex(6)}" }

    context "successful card issuance" do
      it "issues a card with snapshot payout_rate, calculates payout_amount, and generates PIN if required" do
        post "/api/v1/client/cards",
             params: { product_id: product.id, idempotency_key: idempotency_key },
             headers: auth_headers(client_user)

        expect(response).to have_http_status(:created)
        card_data = json_response[:card]
        expect(card_data[:id]).to be_present
        expect(card_data[:activation_number]).to match(/\A[0-9]{16}\z/)
        expect(card_data[:amount]).to eq("100.0")
        expect(card_data[:currency]).to eq("USD")
        expect(card_data[:payout_rate]).to eq("8.5")
        # 100 * 8.5% = 8.50
        expect(card_data[:payout_amount]).to eq("8.5")
        expect(card_data[:status]).to eq("issued")
        # PIN is returned on creation when required/generated
        expect(card_data[:pin]).to be_present
        expect(card_data[:pin]).to match(/\A[0-9]{4}\z/)

        # Verify audit log
        log = AuditLog.where(action: "card.issue", record_type: "Card", record_id: card_data[:id]).last
        expect(log).to be_present
        expect(log.user_id).to eq(client_user.id)
        # Activation number in audit log is masked, PIN is filtered out (LOG-6)
        expect(log.after_values["activation_number"]).to match(/\A\*{12}[0-9]{4}\z/)
        expect(log.after_values).not_to have_key("pin")
      end

      it "accepts a custom PIN from request if provided" do
        post "/api/v1/client/cards",
             params: { product_id: product.id, idempotency_key: idempotency_key, pin: "9988" },
             headers: auth_headers(client_user)

        expect(response).to have_http_status(:created)
        expect(json_response[:card][:pin]).to eq("9988")

        card = Card.find(json_response[:card][:id])
        expect(card.pin).to eq("9988")
      end

      it "does not generate PIN for products that do not require PIN" do
        post "/api/v1/client/cards",
             params: { product_id: product_no_pin.id, idempotency_key: idempotency_key },
             headers: auth_headers(client_user)

        expect(response).to have_http_status(:created)
        expect(json_response[:card]).not_to have_key(:pin)
      end
    end

    context "safe retries and idempotency (CLI-4)" do
      it "returns 200 OK with existing card data and idempotent_replay flag on duplicate request" do
        # First issuance
        post "/api/v1/client/cards",
             params: { product_id: product.id, idempotency_key: idempotency_key },
             headers: auth_headers(client_user)
        expect(response).to have_http_status(:created)
        first_card_id = json_response[:card][:id]

        # Second issuance with identical idempotency_key
        expect {
          post "/api/v1/client/cards",
               params: { product_id: product.id, idempotency_key: idempotency_key },
               headers: auth_headers(client_user)
        }.not_to change(Card, :count)

        expect(response).to have_http_status(:ok)
        expect(json_response[:card][:id]).to eq(first_card_id)
        expect(json_response[:idempotent_replay]).to be(true)
      end
    end

    context "refusal on ineligible requests (CLI-5, LOG-4)" do
      it "refuses issuance and records audit log when product is not assigned to client" do
        expect {
          post "/api/v1/client/cards",
               params: { product_id: unassigned_product.id, idempotency_key: idempotency_key },
               headers: auth_headers(client_user)
        }.to change(AuditLog, :count).by(1)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to include("Product is not assigned to your account")

        refusal_log = AuditLog.where(action: "card.issue_refused").last
        expect(refusal_log.metadata["reason"]).to eq("product_not_assigned")
      end

      it "refuses issuance and records audit log when product is inactive" do
        expect {
          post "/api/v1/client/cards",
               params: { product_id: product_inactive.id, idempotency_key: idempotency_key },
               headers: auth_headers(client_user)
        }.to change(AuditLog, :count).by(1)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to include("Product is currently inactive")

        refusal_log = AuditLog.where(action: "card.issue_refused").last
        expect(refusal_log.metadata["reason"]).to eq("product_inactive")
      end

      it "refuses issuance and records audit log when brand is inactive" do
        expect {
          post "/api/v1/client/cards",
               params: { product_id: product_inactive_brand.id, idempotency_key: idempotency_key },
               headers: auth_headers(client_user)
        }.to change(AuditLog, :count).by(1)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to include("Brand is currently inactive")

        refusal_log = AuditLog.where(action: "card.issue_refused").last
        expect(refusal_log.metadata["reason"]).to eq("brand_inactive")
      end
    end
  end

  describe "POST /api/v1/client/cards/:id/cancel (CLI-6, LOG-4, AUTH-7)" do
    let!(:card) { create(:card, client: client, product: product, status: "issued") }
    let!(:other_card) { create(:card, client: other_client, product: unassigned_product, status: "issued") }

    it "cancels an issued card and records card.cancel audit log" do
      expect {
        post "/api/v1/client/cards/#{card.id}/cancel", headers: auth_headers(client_user)
      }.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response[:card][:status]).to eq("cancelled")
      expect(json_response[:card][:cancelled_at]).to be_present
      expect(card.reload.status).to eq("cancelled")

      cancel_log = AuditLog.where(action: "card.cancel", record_id: card.id).last
      expect(cancel_log).to be_present
      expect(cancel_log.before_values["status"]).to eq("issued")
      expect(cancel_log.after_values["status"]).to eq("cancelled")
    end

    it "refuses cancellation and records audit log if card is already cancelled" do
      card.cancel!

      expect {
        post "/api/v1/client/cards/#{card.id}/cancel", headers: auth_headers(client_user)
      }.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:message]).to eq("Card has already been cancelled")

      refusal_log = AuditLog.where(action: "card.cancel_refused", record_id: card.id).last
      expect(refusal_log.metadata["reason"]).to eq("already_cancelled")
    end

    it "returns 404 Not Found when trying to cancel a card belonging to another client (AUTH-7)" do
      post "/api/v1/client/cards/#{other_card.id}/cancel", headers: auth_headers(client_user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/client/cards/reports/spending (CLI-7, REP-3, AUTH-7)" do
    let!(:active_card) do
      create(:card, client: client, product: product, amount: 100.00, payout_rate: 10.00, status: "issued", issued_at: "2026-06-15 10:00:00")
    end
    let!(:cancelled_card) do
      create(:card, :cancelled, client: client, product: product, amount: 50.00, payout_rate: 10.00, issued_at: "2026-06-20 12:00:00")
    end
    let!(:outside_card) do
      create(:card, client: client, product: product, amount: 200.00, payout_rate: 10.00, status: "issued", issued_at: "2026-01-01 10:00:00")
    end
    let!(:other_client_card) do
      create(:card, client: other_client, product: unassigned_product, amount: 500.00, payout_rate: 5.00, status: "issued", issued_at: "2026-06-15 10:00:00")
    end

    it "aggregates spending and earned payout accurately within date range using SQL" do
      get "/api/v1/client/cards/reports/spending",
          params: { from_date: "2026-06-01", to_date: "2026-06-30" },
          headers: auth_headers(client_user)

      expect(response).to have_http_status(:ok)
      report = json_response[:report]
      expect(report[:total_cards]).to eq(2)
      expect(report[:active_cards]).to eq(1)
      expect(report[:cancelled_cards]).to eq(1)
      expect(report[:gross_spend]).to eq("150.0")
      expect(report[:cancelled_amount]).to eq("50.0")
      expect(report[:net_spend]).to eq("100.0")
      expect(report[:total_payout_earned]).to eq("15.0")
    end
  end

  describe "GET /api/v1/client/cards/reports/cancellation (CLI-7, REP-3, AUTH-7)" do
    let!(:cancelled_card) do
      create(:card, :cancelled, client: client, product: product, amount: 80.00, issued_at: "2026-05-01", cancelled_at: "2026-06-10 14:00:00")
    end
    let!(:other_cancelled_card) do
      create(:card, :cancelled, client: other_client, product: unassigned_product, amount: 150.00, cancelled_at: "2026-06-10 14:00:00")
    end

    it "lists cancelled cards for client with masked activation numbers and accurate summary" do
      get "/api/v1/client/cards/reports/cancellation",
          params: { from_date: "2026-06-01", to_date: "2026-06-30" },
          headers: auth_headers(client_user)

      expect(response).to have_http_status(:ok)
      expect(json_response[:summary][:cancelled_count]).to eq(1)
      expect(json_response[:summary][:cancelled_amount]).to eq("80.0")
      expect(json_response[:cancelled_cards].length).to eq(1)
      card_data = json_response[:cancelled_cards].first
      expect(card_data[:id]).to eq(cancelled_card.id)
      expect(card_data[:activation_number]).to match(/\A\*{12}[0-9]{4}\z/)
      expect(card_data).not_to have_key(:pin)
    end
  end

  describe "Role authorization and security (AUTH-6, AUTH-8)" do
    it "returns 403 Forbidden for admin token on client endpoints (AUTH-6)" do
      get "/api/v1/client/cards", headers: auth_headers(admin_user)
      expect(response).to have_http_status(:forbidden)
      expect(json_response[:message]).to eq("Client access required")
    end

    it "returns 401 Unauthorized for deactivated client user (AUTH-8)" do
      client_user.update!(state: "inactive")
      get "/api/v1/client/cards", headers: auth_headers(client_user)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
