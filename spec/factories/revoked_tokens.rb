# frozen_string_literal: true

FactoryBot.define do
  factory :revoked_token do
    association :user
    sequence(:jti) { SecureRandom.uuid }
    expires_at { 1.hour.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
