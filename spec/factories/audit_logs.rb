FactoryBot.define do
  factory :audit_log do
    action { "auth.login" }
    metadata { {} }
  end
end
