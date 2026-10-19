# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    association :brand
    sequence(:name) { |n| "Gift Card $#{n * 10}" }
    denomination { 50.00 }
    currency { "USD" }
    requires_pin { false }
    state { "active" }
    custom_fields { {} }

    trait :with_pin do
      requires_pin { true }
    end

    trait :inactive do
      state { "inactive" }
    end
  end
end
