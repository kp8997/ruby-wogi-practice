class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :brand, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.decimal :denomination, precision: 12, scale: 2, null: false
      t.string :currency, limit: 3, null: false
      t.boolean :requires_pin, null: false, default: false
      t.string :state, null: false, default: "active"
      t.jsonb :custom_fields, null: false, default: {}
      t.datetime :deleted_at # I intent to use soft delete to keep the data

      t.timestamps
    end

    add_index :products, [ :brand_id, "LOWER(name)" ],
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_products_on_brand_id_and_lower_name"
    add_index :products, :deleted_at

    add_check_constraint :products, "denomination > 0", name: "products_denomination_check"
    add_check_constraint :products, "currency ~ '^[A-Z]{3}$'", name: "products_currency_check"
    add_check_constraint :products, "state IN ('active', 'inactive')", name: "products_state_check"
    add_check_constraint :products, "jsonb_typeof(custom_fields) = 'object'", name: "products_custom_fields_object_check"
  end
end
