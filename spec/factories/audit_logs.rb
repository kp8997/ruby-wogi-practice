# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    action { "auth.login" }
    metadata { {} }
  end
end
