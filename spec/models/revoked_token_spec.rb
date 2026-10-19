# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RevokedToken, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    subject { build(:revoked_token) }

    it { should validate_presence_of(:jti) }
    it { should validate_uniqueness_of(:jti) }
    it { should validate_presence_of(:expires_at) }
  end

  describe "scopes and housekeeping" do
    let!(:active_token) { create(:revoked_token, expires_at: 1.hour.from_now) }
    let!(:expired_token) { create(:revoked_token, :expired) }

    describe ".expired" do
      it "returns only tokens whose expiration time has passed" do
        expect(RevokedToken.expired).to include(expired_token)
        expect(RevokedToken.expired).not_to include(active_token)
      end
    end

    describe ".revoked?" do
      it "returns true when JTI exists" do
        expect(RevokedToken.revoked?(active_token.jti)).to be(true)
      end

      it "returns false when JTI does not exist" do
        expect(RevokedToken.revoked?("unknown-jti")).to be(false)
      end
    end

    describe ".purge_expired!" do
      it "deletes all expired tokens and keeps active tokens" do
        expect {
          RevokedToken.purge_expired!
        }.to change(RevokedToken, :count).by(-1)

        expect(RevokedToken.exists?(expired_token.id)).to be(false)
        expect(RevokedToken.exists?(active_token.id)).to be(true)
      end
    end
  end
end
