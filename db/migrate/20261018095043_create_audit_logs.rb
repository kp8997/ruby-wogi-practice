class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      # Event details (LOG-1, LOG-3, LOG-4)
      t.string :action, null: false
      # Polymorphic target record (Brand, Product, Client, Card)
      t.string :record_type
      t.bigint :record_id
      # State changes (LOG-2)
      t.jsonb :before_values
      t.jsonb :after_values
      # Contextual details (refusal reason, etc.)
      t.jsonb :metadata, null: false, default: {}
      # Request origin (LOG-1)
      t.string :ip_address, limit: 45 # Supports both IPv4 and full IPv6
      t.text :user_agent

      t.timestamps
    end

    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :user_id, :created_at ]
    add_index :audit_logs, [ :action, :created_at ]
    add_index :audit_logs, [ :record_type, :record_id ]

    add_check_constraint :audit_logs, "jsonb_typeof(metadata) = 'object'", name: "audit_logs_metadata_object_check"
  end
end
