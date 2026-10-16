class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.string :state, null: false, default: "active"
      t.jsonb :custom_fields, null: false, default: {}

      t.timestamps
    end

    # lowercase then index for case-insensitive unique
    add_index :brands, "LOWER(name)", unique: true, name: "index_brands_on_lower_name"

    # constraint state
    add_check_constraint :brands, "state IN ('active', 'inactive')", name: "brands_state_check"

    # custom fields is json object
    add_check_constraint :brands, "jsonb_typeof(custom_fields) = 'object'", name: "brands_custom_fields_object_check"
  end
end
