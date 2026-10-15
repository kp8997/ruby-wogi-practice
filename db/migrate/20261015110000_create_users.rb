class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "client"
      t.string :state, null: false, default: "active"
      t.datetime :last_login_at

      t.timestamps
    end

    # Case-insensitive uniqueness enforced by the database
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"
    add_check_constraint :users, "role IN ('admin', 'client')", name: "users_role_check"
    add_check_constraint :users, "state IN ('active', 'inactive')", name: "users_state_check"
  end
end
