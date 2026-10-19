# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    association :user, role: "client"
    sequence(:name) { |n| "Client Company #{n}" }
    payout_rate { 5.00 }
  end
end
