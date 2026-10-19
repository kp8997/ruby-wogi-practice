# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_one :client, dependent: :destroy
  has_many :revoked_tokens, dependent: :delete_all

  enum :role, { admin: "admin", client: "client" }, prefix: true, validate: true
  enum :state, { active: "active", inactive: "inactive" }, prefix: true, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
