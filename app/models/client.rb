# frozen_string_literal: true

class Client < ApplicationRecord
  include Auditable

  belongs_to :user

  has_many :client_product_accesses, dependent: :destroy
  has_many :products, through: :client_product_accesses
  has_many :cards, dependent: :restrict_with_error

  validates :name, presence: true
  validates :payout_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :user_must_have_client_role

  private

  def user_must_have_client_role
    errors.add(:user, "must have the client role") if user && !user.role_client?
  end
end
