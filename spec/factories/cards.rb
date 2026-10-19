# frozen_string_literal: true

FactoryBot.define do
  factory :card do
    association :client
    association :product
    sequence(:idempotency_key) { |n| "idemp-key-#{n}" }
    activation_number { Card.generate_activation_number }
    amount { product.denomination }
    currency { product.currency }
    payout_rate { client.payout_rate }
    status { "issued" }
    issued_at { Time.current }

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { Time.current }
    end
  end
end
