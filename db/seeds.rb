# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Passwords come from ENV; dev defaults are used only outside production.

def seed_password(env_key, dev_default)
  ENV[env_key].presence || (Rails.env.production? ? raise("#{env_key} must be set in production") : dev_default)
end

# --- Admin ---
# Idempotency here, rails db:seed many times won't affect or duplicate data
admin = User.find_or_initialize_by(email: ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com"))
if admin.new_record?
  admin.assign_attributes(password: seed_password("SEED_ADMIN_PASSWORD", "Admin@12345"), role: "admin", state: "active")
  admin.save!
end

# --- Demo clients (non-production only) ---
unless Rails.env.production?
  [
    { email: "client1@example.com", name: "Acme Retail", payout_rate: 5.00 },
    { email: "client2@example.com", name: "Nova Partners", payout_rate: 7.50 }
  ].each do |attrs|
    user = User.find_or_initialize_by(email: attrs[:email])
    if user.new_record?
      user.assign_attributes(password: "Client@12345", role: "client", state: "active")
      user.save!
    end
    Client.find_or_create_by!(user: user) do |c|
      c.name = attrs[:name]
      c.payout_rate = attrs[:payout_rate]
    end
  end
end

puts "Seeded: #{User.role_admin.count} admin(s), #{Client.count} client(s)"
