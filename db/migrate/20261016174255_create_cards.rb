class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :client, null: false, foreign_key: { on_delete: :restrict }
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.string :activation_number, limit: 16, null: false
      t.string :pin
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "issued"
      t.datetime :issued_at, null: false
      t.datetime :cancelled_at
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, limit: 3, null: false
      t.decimal :payout_rate, precision: 5, scale: 2, null: false
      t.decimal :payout_amount, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :cards, :activation_number, unique: true
    add_index :cards, [ :client_id, :idempotency_key ], unique: true
    add_index :cards, [ :client_id, :issued_at ]
    add_index :cards, [ :product_id, :issued_at ]

    add_check_constraint :cards, "activation_number ~ '^[0-9]{16}$'", name: "cards_activation_number_format_check"

    add_check_constraint :cards,
      "(status = 'issued' AND cancelled_at IS NULL) OR (status = 'cancelled' AND cancelled_at IS NOT NULL)",
      name: "cards_lifecycle_check"
    add_check_constraint :cards, "status IN ('issued', 'cancelled')", name: "cards_status_check"
    add_check_constraint :cards, "amount > 0", name: "cards_amount_check"
    add_check_constraint :cards, "payout_rate >= 0 AND payout_rate <= 100", name: "cards_payout_rate_check"
  end
end
