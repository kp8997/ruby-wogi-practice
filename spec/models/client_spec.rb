# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Client, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:client_product_accesses).dependent(:destroy) }
    it { should have_many(:products).through(:client_product_accesses) }
    it { should have_many(:cards).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:client) }

    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:payout_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }

    context "user_must_have_client_role" do
      it "allows client when user has role 'client'" do
        client_user = create(:user, role: "client")
        client = build(:client, user: client_user)
        expect(client).to be_valid
      end

      it "rejects client when user has role 'admin'" do
        admin_user = create(:user, :admin)
        client = build(:client, user: admin_user)
        expect(client).not_to be_valid
        expect(client.errors[:user]).to include("must have the client role")
      end
    end
  end

  describe "auditing (Auditable)" do
    it "logs client.create on creation" do
      expect {
        create(:client, name: "New Client Corp")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("client.create")
      expect(log.record_type).to eq("Client")
    end

    it "logs client.update on attribute change" do
      client = create(:client, payout_rate: 5.00)

      expect {
        client.update!(payout_rate: 8.50)
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("client.update")
      expect(log.before_values).to eq({ "payout_rate" => "5.0" })
      expect(log.after_values).to eq({ "payout_rate" => "8.5" })
    end
  end
end
