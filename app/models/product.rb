class Product < ApplicationRecord
  include Auditable

  belongs_to :brand

  has_many :cards, dependent: :restrict_with_error
  has_many :client_product_accesses, dependent: :destroy
  has_many :clients, through: :client_product_accesses

  enum :state, { active: "active", inactive: "inactive" }

  normalizes :name, with: ->(name) { name.strip }
  normalizes :currency, with: ->(curr) { curr.strip.upcase }

  # define some query functions for soft delete feature
  scope :kept, -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand_id, case_sensitive: false, conditions: -> { kept } }, if: -> { deleted_at.nil? }
  validates :denomination, numericality: { greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validate :validate_custom_fields

  # Soft delete helper methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def discarded?
    deleted_at.present?
  end

  private

  def validate_custom_fields
    unless custom_fields.is_a?(Hash)
      errors.add(:custom_fields, "must be a valid key-value object")
      return
    end

    if custom_fields.keys.size > 5
      errors.add(:custom_fields, "cannot contain more than 5 custom fields (current: #{custom_fields.keys.size})")
    end

    custom_fields.each do |key, value|
      if key.blank? || !key.is_a?(String)
        errors.add(:custom_fields, "keys must be non-empty strings")
      end
      if value.is_a?(Hash) || value.is_a?(Array)
        errors.add(:custom_fields, "values must be simple scalar types, not nested structures")
      end
    end
  end
end
