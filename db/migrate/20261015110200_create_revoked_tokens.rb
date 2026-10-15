class CreateRevokedTokens < ActiveRecord::Migration[8.1]
  def change
    # Logout support: JWTs are stateless, so on logout we store the token's
    # jti (unique id) here and reject it until it would have expired anyway.
    create_table :revoked_tokens do |t|
      t.string :jti, null: false
      t.references :user, null: false, foreign_key: true
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :revoked_tokens, :jti, unique: true
    add_index :revoked_tokens, :expires_at
  end
end
