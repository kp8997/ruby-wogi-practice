require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe "associations" do
    it { should have_many(:products).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:brand) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should define_enum_for(:state).with_values(active: "active", inactive: "inactive").backed_by_column_of_type(:string) }

    context "custom_fields validation" do
      it "allows up to 5 scalar custom fields" do
        brand = build(:brand, custom_fields: { "website" => "https://brand.com", "tier" => "gold" })
        expect(brand).to be_valid
      end

      it "rejects more than 5 custom fields" do
        fields = 6.times.to_h { |i| ["field_#{i}", "value_#{i}"] }
        brand = build(:brand, custom_fields: fields)
        expect(brand).not_to be_valid
        expect(brand.errors[:custom_fields]).to include(/cannot contain more than 5/)
      end

      it "rejects nested objects or arrays in custom fields" do
        brand = build(:brand, custom_fields: { "nested" => { "key" => "val" } })
        expect(brand).not_to be_valid
        expect(brand.errors[:custom_fields]).to include(/must be simple scalar types/)
      end
    end
  end

  describe "normalization" do
    it "strips leading and trailing whitespaces from name" do
      brand = create(:brand, name: "   Nike Sports   ")
      expect(brand.name).to eq("Nike Sports")
    end
  end

  describe "auditing (Auditable)" do
    it "logs brand.create on creation" do
      expect {
        create(:brand, name: "Apple")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("brand.create")
      expect(log.record_type).to eq("Brand")
    end

    it "logs brand.update on attribute changes" do
      brand = create(:brand, name: "Original Name")

      expect {
        brand.update!(name: "Renamed")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("brand.update")
      expect(log.before_values).to eq({ "name" => "Original Name" })
      expect(log.after_values).to eq({ "name" => "Renamed" })
    end

    it "logs brand.state_change when toggling state" do
      brand = create(:brand, state: "active")

      expect {
        brand.update!(state: "inactive")
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("brand.state_change")
      expect(log.before_values).to eq({ "state" => "active" })
      expect(log.after_values).to eq({ "state" => "inactive" })
    end
  end
end
