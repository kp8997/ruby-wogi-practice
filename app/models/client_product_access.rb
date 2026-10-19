# frozen_string_literal: true

class ClientProductAccess < ApplicationRecord
  belongs_to :client
  belongs_to :product

  validates :product_id, uniqueness: {
    scope: :client_id,
    message: "has already been granted to this client"
  }
end
