class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.decimal :payout_rate, precision: 5, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :clients, "payout_rate >= 0 AND payout_rate <= 100", name: "clients_payout_rate_check"
  end
end
