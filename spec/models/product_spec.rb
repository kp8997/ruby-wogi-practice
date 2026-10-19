require 'rails_helper'

RSpec.describe Product, type: :model do
  describe "associations" do
    it { should belong_to(:brand) }
    it { should have_many(:cards).dependent(:restrict_with_error) }
    it { should have_many(:client_product_accesses).dependent(:destroy) }
    it { should have_many(:clients).through(:client_product_accesses) }
  end

  describe "validations" do
    subject { build(:product) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:brand_id).case_insensitive }
    it { should validate_numericality_of(:denomination).is_greater_than(0) }
    it { should validate_presence_of(:currency) }
    it { should allow_value("USD").for(:currency) }
    it { should allow_value("EUR").for(:currency) }
    it { should_not allow_value("US").for(:currency) }
    it { should_not allow_value("USDD").for(:currency) }
    it { should define_enum_for(:state).with_values(active: "active", inactive: "inactive").backed_by_column_of_type(:string) }

    context "custom_fields validation" do
      it "allows up to 5 scalar custom fields" do
        product = build(:product, custom_fields: { "sku" => "SKU-001", "category" => "Beverage" })
        expect(product).to be_valid
      end

      it "rejects more than 5 custom fields" do
        fields = 6.times.to_h { |i| ["key_#{i}", "val_#{i}"] }
        product = build(:product, custom_fields: fields)
        expect(product).not_to be_valid
        expect(product.errors[:custom_fields]).to include(/cannot contain more than 5/)
      end

      it "rejects nested objects or arrays in custom fields" do
        product = build(:product, custom_fields: { "nested" => { "level" => 1 } })
        expect(product).not_to be_valid
        expect(product.errors[:custom_fields]).to include(/must be simple scalar types/)
      end
    end
  end

  describe "normalization" do
    it "strips whitespace from name" do
      product = create(:product, name: "   Coffee $25   ")
      expect(product.name).to eq("Coffee $25")
    end

    it "strips and upcases currency" do
      product = create(:product, currency: " usd ")
      expect(product.currency).to eq("USD")
    end
  end

  describe "soft delete" do
    let!(:product) { create(:product) }

    it "marks record as discarded on soft_delete!" do
      expect {
        product.soft_delete!
      }.to change { product.discarded? }.from(false).to(true)
      expect(product.deleted_at).to be_present
    end

    it "filters kept vs discarded in scopes" do
      discarded_product = create(:product, deleted_at: Time.current)

      expect(Product.kept).to include(product)
      expect(Product.kept).not_to include(discarded_product)

      expect(Product.discarded).to include(discarded_product)
      expect(Product.discarded).not_to include(product)
    end

    it "allows reusing the name under the same brand after soft delete" do
      brand = product.brand
      original_name = product.name
      product.soft_delete!

      new_product = build(:product, brand: brand, name: original_name)
      expect(new_product).to be_valid
    end
  end

  describe "auditing (Auditable)" do
    let!(:brand) { create(:brand) }

    it "logs product.create on creation" do
      expect {
        create(:product, brand: brand, name: "New Voucher")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("product.create")
      expect(log.record_type).to eq("Product")
    end

    it "logs product.update on attribute change" do
      product = create(:product, denomination: 50.00)

      expect {
        product.update!(denomination: 75.00)
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("product.update")
      expect(log.before_values).to eq({ "denomination" => "50.0" })
      expect(log.after_values).to eq({ "denomination" => "75.0" })
    end

    it "logs product.state_change on state toggle" do
      product = create(:product, state: "active")

      expect {
        product.update!(state: "inactive")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("product.state_change")
      expect(log.before_values).to eq({ "state" => "active" })
      expect(log.after_values).to eq({ "state" => "inactive" })
    end

    it "logs product.delete on soft_delete!" do
      product = create(:product)

      expect {
        product.soft_delete!
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("product.delete")
      expect(log.before_values).to have_key("deleted_at")
      expect(log.after_values["deleted_at"]).to be_present
    end
  end
end
