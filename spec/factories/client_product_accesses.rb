# frozen_string_literal: true

FactoryBot.define do
  factory :client_product_access do
    association :client
    association :product
  end
end
