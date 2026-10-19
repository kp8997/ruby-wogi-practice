# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  describe "associations" do
    it { should belong_to(:user).optional }
  end

  describe "validations" do
    it { should validate_presence_of(:action) }
  end

  describe "append-only immutability" do
    let(:log) { create(:audit_log, action: "brand.create") }

    it "is not readonly before being persisted" do
      new_log = build(:audit_log)
      expect(new_log.readonly?).to be(false)
    end

    it "becomes readonly once persisted" do
      expect(log.readonly?).to be(true)
    end

    it "prevents updating an existing audit log" do
      expect {
        log.update(action: "brand.tampered")
      }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "prevents deleting an existing audit log" do
      expect {
        log.destroy
      }.to raise_error(ActiveRecord::ReadOnlyRecord, "AuditLog cannot be deleted.")
    end
  end

  describe "scopes" do
    let(:user_1) { create(:user) }
    let(:user_2) { create(:user) }

    let!(:log_old) do
      create(:audit_log,
             user: user_1,
             action: "auth.login",
             record_type: "User",
             record_id: user_1.id,
             created_at: 3.days.ago)
    end

    let!(:log_new) do
      create(:audit_log,
             user: user_2,
             action: "card.issue",
             record_type: "Card",
             record_id: 99,
             created_at: 1.day.ago)
    end

    describe ".recent" do
      it "orders records newest first by created_at desc" do
        expect(AuditLog.recent.to_a).to eq([log_new, log_old])
      end
    end

    describe ".for_action" do
      it "filters by action when provided" do
        expect(AuditLog.for_action("auth.login")).to include(log_old)
        expect(AuditLog.for_action("auth.login")).not_to include(log_new)
      end

      it "returns all records when action is blank" do
        expect(AuditLog.for_action(nil).count).to eq(2)
      end
    end

    describe ".for_user" do
      it "filters by user_id when provided" do
        expect(AuditLog.for_user(user_1.id)).to include(log_old)
        expect(AuditLog.for_user(user_1.id)).not_to include(log_new)
      end

      it "returns all records when user_id is blank" do
        expect(AuditLog.for_user(nil).count).to eq(2)
      end
    end

    describe ".for_record" do
      it "filters by polymorphic record_type and record_id" do
        expect(AuditLog.for_record("Card", 99)).to include(log_new)
        expect(AuditLog.for_record("Card", 99)).not_to include(log_old)
      end

      it "returns all records when type or id is blank" do
        expect(AuditLog.for_record(nil, nil).count).to eq(2)
      end
    end

    describe ".in_date_range" do
      it "filters within date range" do
        results = AuditLog.in_date_range(2.days.ago, Time.current)
        expect(results).to include(log_new)
        expect(results).not_to include(log_old)
      end

      it "returns all records when range bounds are blank" do
        expect(AuditLog.in_date_range(nil, nil).count).to eq(2)
      end
    end
  end
end
