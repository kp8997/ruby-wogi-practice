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

ActiveRecord::Schema[8.1].define(version: 2026_10_18_095043) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "record_type"
    t.bigint "record_id"
    t.jsonb "before_values"
    t.jsonb "after_values"
    t.jsonb "metadata", default: {}, null: false
    t.string "ip_address", limit: 45
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_audit_logs_on_action_and_created_at"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["record_type", "record_id"], name: "index_audit_logs_on_record_type_and_record_id"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
    t.check_constraint "jsonb_typeof(metadata) = 'object'::text", name: "audit_logs_metadata_object_check"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "state", default: "active", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_brands_on_lower_name", unique: true
    t.check_constraint "jsonb_typeof(custom_fields) = 'object'::text", name: "brands_custom_fields_object_check"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "brands_state_check"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "product_id", null: false
    t.string "activation_number", limit: 16, null: false
    t.string "pin"
    t.string "idempotency_key", null: false
    t.string "status", default: "issued", null: false
    t.datetime "issued_at", null: false
    t.datetime "cancelled_at"
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "currency", limit: 3, null: false
    t.decimal "payout_rate", precision: 5, scale: 2, null: false
    t.decimal "payout_amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activation_number"], name: "index_cards_on_activation_number", unique: true
    t.index ["client_id", "idempotency_key"], name: "index_cards_on_client_id_and_idempotency_key", unique: true
    t.index ["client_id", "issued_at"], name: "index_cards_on_client_id_and_issued_at"
    t.index ["client_id"], name: "index_cards_on_client_id"
    t.index ["product_id", "issued_at"], name: "index_cards_on_product_id_and_issued_at"
    t.index ["product_id"], name: "index_cards_on_product_id"
    t.check_constraint "activation_number::text ~ '^[0-9]{16}$'::text", name: "cards_activation_number_format_check"
    t.check_constraint "amount > 0::numeric", name: "cards_amount_check"
    t.check_constraint "payout_rate >= 0::numeric AND payout_rate <= 100::numeric", name: "cards_payout_rate_check"
    t.check_constraint "status::text = 'issued'::text AND cancelled_at IS NULL OR status::text = 'cancelled'::text AND cancelled_at IS NOT NULL", name: "cards_lifecycle_check"
    t.check_constraint "status::text = ANY (ARRAY['issued'::character varying, 'cancelled'::character varying]::text[])", name: "cards_status_check"
  end

  create_table "client_product_accesses", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "product_id"], name: "index_client_product_accesses_on_client_id_and_product_id", unique: true
    t.index ["client_id"], name: "index_client_product_accesses_on_client_id"
    t.index ["product_id"], name: "index_client_product_accesses_on_product_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "payout_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_clients_on_user_id", unique: true
    t.check_constraint "payout_rate >= 0::numeric AND payout_rate <= 100::numeric", name: "clients_payout_rate_check"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.decimal "denomination", precision: 12, scale: 2, null: false
    t.string "currency", limit: 3, null: false
    t.boolean "requires_pin", default: false, null: false
    t.string "state", default: "active", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "brand_id, lower((name)::text)", name: "index_products_on_brand_id_and_lower_name", unique: true, where: "(deleted_at IS NULL)"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "products_currency_check"
    t.check_constraint "denomination > 0::numeric", name: "products_denomination_check"
    t.check_constraint "jsonb_typeof(custom_fields) = 'object'::text", name: "products_custom_fields_object_check"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "products_state_check"
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

  add_foreign_key "audit_logs", "users", on_delete: :nullify
  add_foreign_key "cards", "clients", on_delete: :restrict
  add_foreign_key "cards", "products", on_delete: :restrict
  add_foreign_key "client_product_accesses", "clients", on_delete: :cascade
  add_foreign_key "client_product_accesses", "products", on_delete: :cascade
  add_foreign_key "clients", "users"
  add_foreign_key "products", "brands", on_delete: :restrict
  add_foreign_key "revoked_tokens", "users"
end
