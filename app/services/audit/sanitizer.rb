# frozen_string_literal: true

module Audit
  class Sanitizer
    FILTERED_KEYS = %w[password password_digest password_confirmation pin].freeze

    def self.clean(data)
      return nil if data.blank?
      # Convert hash to string keys and deep clean
      data.deep_stringify_keys.each_with_object({}) do |(key, value), result|
        if FILTERED_KEYS.include?(key)
          next
        elsif key == "activation_number" && value.present?
          # Mask activation numbers: ************1234
          result[key] = "*" * 12 + value.to_s.last(4)
        elsif value.is_a?(Hash)
          # Recursive sanitize for nested hash
          result[key] = clean(value)
        else
          result[key] = value
        end
      end
    end
  end
end
