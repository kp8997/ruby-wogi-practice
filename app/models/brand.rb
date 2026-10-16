class Brand < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  enum :state, { active: "active", inactive: "inactive" }

  # Auto-strip whitespaces from brand name
  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validate :validate_custom_fields

  private

  def validate_custom_fields
    unless custom_fields.is_a?(Hash)
      errors.add(:custom_fields, "must be a valid key-value object")
      return
    end
    # Check the maximum 5 custom fields limit
    if custom_fields.keys.size > 5
      errors.add(:custom_fields, "cannot contain more than 5 custom fields (current: #{custom_fields.keys.size})")
    end
    # Check keys are strings and values are primitives type
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
