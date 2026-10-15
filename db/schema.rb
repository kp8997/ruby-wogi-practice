# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_15_110200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "payout_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_clients_on_user_id", unique: true
    t.check_constraint "payout_rate >= 0::numeric AND payout_rate <= 100::numeric", name: "clients_payout_rate_check"
  end

  create_table "revoked_tokens", force: :cascade do |t|
    t.string "jti", null: false
    t.bigint "user_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_revoked_tokens_on_expires_at"
    t.index ["jti"], name: "index_revoked_tokens_on_jti", unique: true
    t.index ["user_id"], name: "index_revoked_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "client", null: false
    t.string "state", default: "active", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'client'::character varying]::text[])", name: "users_role_check"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "users_state_check"
  end

  add_foreign_key "clients", "users"
  add_foreign_key "revoked_tokens", "users"
end
