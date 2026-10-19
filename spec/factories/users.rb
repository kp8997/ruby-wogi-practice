# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password@123" }
    role { "client" }
    state { "active" }

    trait :admin do
      role { "admin" }
    end

    trait :inactive do
      state { "inactive" }
    end
  end
end
