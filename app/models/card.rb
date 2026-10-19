# frozen_string_literal: true

class Card < ApplicationRecord
  belongs_to :client
  belongs_to :product

  encrypts :pin

  enum :status, { issued: "issued", cancelled: "cancelled" }

  validates :activation_number, presence: true,
                                uniqueness: true,
                                format: { with: /\A[0-9]{16}\z/, message: "must be exactly 16 numeric digits" }
  validates :idempotency_key, presence: true, uniqueness: { scope: :client_id }
  validates :amount, numericality: { greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :payout_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :payout_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :issued_at, presence: true

  before_validation :set_defaults_and_snapshots, on: :create

  def cancel!
    return false if cancelled?

    affected_rows = self.class.where(id: id, status: :issued).update_all(
      status: "cancelled",
      cancelled_at: Time.current,
      updated_at: Time.current
    )

    if affected_rows > 0
      reload
      true
    else
      false
    end
  end

  # Create unique number, if number is existing in database, loop the process
  def self.generate_activation_number
    loop do
      number = SecureRandom.random_number(10**16).to_s.rjust(16, "0")
      break number unless exists?(activation_number: number)
    end
  end

  private

  # payout_rate will be populated in card issue method by copy from current client
  # Calculate payout_amound (real money) base on payout_rate
  def set_defaults_and_snapshots
    self.issued_at ||= Time.current
    self.activation_number ||= self.class.generate_activation_number

    if amount.present? && payout_rate.present?
      self.payout_amount ||= (amount * payout_rate / 100.0).round(2)
    end
  end
end
