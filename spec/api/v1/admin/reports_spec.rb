# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "V1::Admin::Reports API", type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:client_user) { create(:user, role: "client") }
  let!(:client) { create(:client, user: client_user, name: "Acme Retail", payout_rate: 10.0) }

  let!(:brand_1) { create(:brand, name: "Alpha Books") }
  let!(:product_1) { create(:product, brand: brand_1, denomination: 50.0) }

  let!(:brand_2) { create(:brand, name: "Beta Coffee") }
  let!(:product_2) { create(:product, brand: brand_2, denomination: 20.0) }

  # Card 1: Alpha Books, $50, payout 10% ($5.00), issued
  let!(:card_1) do
    create(:card,
           client: client,
           product: product_1,
           amount: 50.0,
           payout_rate: 10.0,
           payout_amount: 5.0,
           status: "issued",
           issued_at: 2.days.ago)
  end

  # Card 2: Alpha Books, $50, payout 10% ($5.00), cancelled
  let!(:card_2) do
    create(:card,
           client: client,
           product: product_1,
           amount: 50.0,
           payout_rate: 10.0,
           payout_amount: 5.0,
           status: "cancelled",
           issued_at: 3.days.ago,
           cancelled_at: 1.day.ago)
  end

  # Card 3: Beta Coffee, $20, payout 10% ($2.00), issued
  let!(:card_3) do
    create(:card,
           client: client,
           product: product_2,
           amount: 20.0,
           payout_rate: 10.0,
           payout_amount: 2.0,
           status: "issued",
           issued_at: 1.day.ago)
  end

  describe "GET /api/v1/admin/reports/brands (REP-1, ADM-8)" do
    context "when authenticated as admin" do
      it "returns aggregated metrics grouped by brand" do
        get "/api/v1/admin/reports/brands", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:summary][:total_gross_volume].to_f).to eq(120.0)
        expect(json_response[:summary][:total_cards]).to eq(3)
        expect(json_response[:summary][:total_cancelled]).to eq(1)

        alpha_report = json_response[:brands].find { |b| b[:brand_name] == "Alpha Books" }
        expect(alpha_report[:total_cards]).to eq(2)
        expect(alpha_report[:gross_volume].to_f).to eq(100.0)
        expect(alpha_report[:cancelled_cards]).to eq(1)
        expect(alpha_report[:active_cards]).to eq(1)
        expect(alpha_report[:net_volume].to_f).to eq(50.0)

        beta_report = json_response[:brands].find { |b| b[:brand_name] == "Beta Coffee" }
        expect(beta_report[:total_cards]).to eq(1)
        expect(beta_report[:gross_volume].to_f).to eq(20.0)
      end

      it "filters totals within date range" do
        from = 1.day.ago.beginning_of_day.to_s
        to = Time.current.end_of_day.to_s

        get "/api/v1/admin/reports/brands", params: { from_date: from, to_date: to }, headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:summary][:total_cards]).to eq(1)
        expect(json_response[:summary][:total_gross_volume].to_f).to eq(20.0)
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/reports/brands", headers: auth_headers(client_user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/admin/reports/clients (REP-2, ADM-8)" do
    context "when authenticated as admin" do
      it "returns aggregated financial metrics grouped by client" do
        get "/api/v1/admin/reports/clients", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response[:summary][:total_gross_spend].to_f).to eq(120.0)
        expect(json_response[:summary][:total_payout].to_f).to eq(12.0)
        expect(json_response[:summary][:total_cards]).to eq(3)
        expect(json_response[:summary][:total_cancelled]).to eq(1)

        client_report = json_response[:clients].find { |c| c[:client_id] == client.id }
        expect(client_report[:client_name]).to eq("Acme Retail")
        expect(client_report[:total_cards]).to eq(3)
        expect(client_report[:gross_spend].to_f).to eq(120.0)
        expect(client_report[:total_payout].to_f).to eq(12.0)
        expect(client_report[:cancelled_cards]).to eq(1)
        expect(client_report[:active_cards]).to eq(2)
      end
    end

    context "when authenticated as client (AUTH-6)" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/reports/clients", headers: auth_headers(client_user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
