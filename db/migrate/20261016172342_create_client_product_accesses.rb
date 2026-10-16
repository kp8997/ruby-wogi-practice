class CreateClientProductAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :client_product_accesses do |t|
      t.references :client, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # Composite key for client_id and product_id -> no duplication
    add_index :client_product_accesses, [ :client_id, :product_id ], unique: true
  end
end
