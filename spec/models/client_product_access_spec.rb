# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClientProductAccess, type: :model do
  describe "associations" do
    it { should belong_to(:client) }
    it { should belong_to(:product) }
  end

  describe "validations" do
    subject { create(:client_product_access) }

    it {
      should validate_uniqueness_of(:product_id)
        .scoped_to(:client_id)
        .with_message("has already been granted to this client")
    }
  end
end
