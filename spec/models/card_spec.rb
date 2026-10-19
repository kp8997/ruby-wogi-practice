# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Card, type: :model do
  describe "associations" do
    it { should belong_to(:client) }
    it { should belong_to(:product) }
  end

  describe "validations" do
    subject { create(:card) }

    it { should validate_presence_of(:idempotency_key) }
    it { should validate_uniqueness_of(:idempotency_key).scoped_to(:client_id) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:currency) }
    it { should allow_value("USD").for(:currency) }
    it { should_not allow_value("US").for(:currency) }
    it { should validate_numericality_of(:payout_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { should validate_numericality_of(:payout_amount).is_greater_than_or_equal_to(0) }
    it { should define_enum_for(:status).with_values(issued: "issued", cancelled: "cancelled").backed_by_column_of_type(:string) }

    context "activation_number" do
      it "validates uniqueness of activation_number" do
        card = create(:card)
        duplicate = build(:card, activation_number: card.activation_number)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:activation_number]).to include("has already been taken")
      end

      it "validates that activation_number is exactly 16 numeric digits" do
        expect(build(:card, activation_number: "1234567890123456")).to be_valid
        expect(build(:card, activation_number: "12345")).not_to be_valid
        expect(build(:card, activation_number: "123456789012345A")).not_to be_valid
      end
    end
  end

  describe "PIN encryption" do
    it "encrypts PIN in the database and decrypts on read" do
      card = create(:card, pin: "1234")
      expect(card.pin).to eq("1234")

      # Raw DB column should not store plain text PIN
      raw_pin = Card.connection.select_value("SELECT pin FROM cards WHERE id = #{card.id}")
      expect(raw_pin).not_to eq("1234")
      expect(raw_pin).to be_present
    end
  end

  describe "defaults and snapshot calculations" do
    it "auto-generates a 16-digit activation number on creation" do
      card = create(:card, activation_number: nil)
      expect(card.activation_number).to be_present
      expect(card.activation_number).to match(/\A[0-9]{16}\z/)
    end

    it "sets issued_at to current time on creation" do
      card = create(:card, issued_at: nil)
      expect(card.issued_at).to be_within(2.seconds).of(Time.current)
    end

    it "calculates payout_amount accurately as a snapshot" do
      card = create(:card, amount: 50.00, payout_rate: 7.50, payout_amount: nil)
      # 50.00 * 7.5% = 3.75
      expect(card.payout_amount).to eq(3.75)
    end

    it "preserves original payout_amount snapshot even if rate changes later" do
      card = create(:card, amount: 100.00, payout_rate: 10.00)
      expect(card.payout_amount).to eq(10.00)

      # Client changes payout rate
      card.client.update!(payout_rate: 20.00)
      card.reload
      expect(card.payout_amount).to eq(10.00) # Past card remains 10.00
    end
  end

  describe "#cancel!" do
    let!(:card) { create(:card, status: "issued") }

    it "transitions an issued card to cancelled" do
      expect(card.cancel!).to be(true)
      expect(card.reload.status).to eq("cancelled")
      expect(card.cancelled_at).to be_present
    end

    it "returns false and does not alter cancelled_at if already cancelled" do
      card.cancel!
      original_cancelled_at = card.cancelled_at

      expect(card.cancel!).to be(false)
      expect(card.reload.cancelled_at).to eq(original_cancelled_at)
    end
  end

  describe ".generate_activation_number" do
    it "returns a 16-digit string" do
      number = Card.generate_activation_number
      expect(number).to match(/\A[0-9]{16}\z/)
    end
  end
end
