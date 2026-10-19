# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_one(:client).dependent(:destroy) }
    it { should have_many(:revoked_tokens).dependent(:delete_all) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should have_secure_password }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_length_of(:password).is_at_least(8) }

    it { should allow_value("user@example.com").for(:email) }
    it { should allow_value("john.doe+tag@sub.domain.co").for(:email) }
    it { should_not allow_value("invalid_email").for(:email) }
    it { should_not allow_value("user@").for(:email) }
    it { should_not allow_value("@domain.com").for(:email) }

    it { should define_enum_for(:role).with_values(admin: "admin", client: "client").with_prefix(:role).backed_by_column_of_type(:string) }
    it { should define_enum_for(:state).with_values(active: "active", inactive: "inactive").with_prefix(:state).backed_by_column_of_type(:string) }
  end

  describe "normalization" do
    it "strips and downcases email address" do
      user = create(:user, email: "   User.Test@EXAMPLE.COM   ")
      expect(user.email).to eq("user.test@example.com")
    end
  end
end
