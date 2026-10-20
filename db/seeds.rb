# Passwords come from ENV; dev defaults are used if not provided.
def seed_password(env_key, dev_default)
  ENV[env_key].presence || dev_default
end

puts "start seeding"

# admin
admin = User.find_or_initialize_by(email: ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com"))
if admin.new_record?
  admin.assign_attributes(
    password: seed_password("SEED_ADMIN_PASSWORD", "Admin@12345"),
    role: "admin",
    state: "active"
  )
  admin.save!
  puts "created admin: #{admin.email}"
end

# clients
clients_data = [
  { email: "client1@example.com", name: "Acme Retail", payout_rate: 5.00, state: "active" },
  { email: "client2@example.com", name: "Nova Partners", payout_rate: 7.50, state: "active" },
  { email: "inactive_client@example.com", name: "Old Store", payout_rate: 10.00, state: "inactive" }
]
clients = {}
clients_data.each do |data|
  user = User.find_or_initialize_by(email: data[:email])
  if user.new_record?
    user.assign_attributes(password: "Client@12345", role: "client", state: data[:state])
    user.save!
  end
  client = Client.find_or_create_by!(user: user) do |c|
    c.name = data[:name]
    c.payout_rate = data[:payout_rate]
  end
  clients[data[:email]] = client
  puts "created client: #{client.name} (#{user.email}) - state: #{user.state}"
end

# brands
brands_data = [
  {
    name: "Acme Books",
    state: "active",
    custom_fields: { "category" => "Books & Stationery", "website" => "https://acmebooks.com" }
  },
  {
    name: "Nova Coffee",
    state: "active",
    custom_fields: { "category" => "Food & Beverage", "support_email" => "support@novacoffee.com" }
  },
  {
    name: "Zen Spa",
    state: "inactive",
    custom_fields: { "category" => "Wellness & Beauty" }
  }
]
brands = {}
brands_data.each do |data|
  brand = Brand.find_or_create_by!(name: data[:name]) do |b|
    b.state = data[:state]
    b.custom_fields = data[:custom_fields]
  end
  brands[data[:name]] = brand
  puts "created brand: #{brand.name} (state: #{brand.state})"
end

# products
products_data = [
  # Acme Books products
  { brand: brands["Acme Books"], name: "Acme $25 E-Gift", denomination: 25.00, currency: "USD", requires_pin: false, state: "active" },
  { brand: brands["Acme Books"], name: "Acme $50 Premium Card", denomination: 50.00, currency: "USD", requires_pin: true, state: "active" },
  { brand: brands["Acme Books"], name: "Acme $100 Holiday Voucher", denomination: 100.00, currency: "USD", requires_pin: true, state: "inactive" },

  { brand: brands["Nova Coffee"], name: "Nova Morning $10", denomination: 10.00, currency: "USD", requires_pin: false, state: "active" },
  { brand: brands["Nova Coffee"], name: "Nova Roastery $50", denomination: 50.00, currency: "USD", requires_pin: false, state: "active" },

  { brand: brands["Zen Spa"], name: "Zen Spa $100 Massage", denomination: 100.00, currency: "USD", requires_pin: true, state: "active" }
]
products = {}
products_data.each do |data|
  product = Product.find_or_create_by!(brand: data[:brand], name: data[:name]) do |p|
    p.denomination = data[:denomination]
    p.currency = data[:currency]
    p.requires_pin = data[:requires_pin]
    p.state = data[:state]
    p.custom_fields = { "sku" => "SKU-#{SecureRandom.hex(3).upcase}" }
  end
  products[data[:name]] = product
  puts "created product: #{product.name} - #{product.denomination} #{product.currency} (state: #{product.state})"
end

# client product permission
acme_client = clients["client1@example.com"]
[
  products["Acme $25 E-Gift"],
  products["Acme $50 Premium Card"],
  products["Nova Morning $10"]
].each do |prod|
  ClientProductAccess.find_or_create_by!(client: acme_client, product: prod)
end
puts "finish client product permission"

nova_client = clients["client2@example.com"]
[
  products["Nova Morning $10"],
  products["Nova Roastery $50"],
  products["Acme $50 Premium Card"]
].each do |prod|
  ClientProductAccess.find_or_create_by!(client: nova_client, product: prod)
end
puts "finish client product permission"

# cards
Card.find_or_create_by!(idempotency_key: "seed-card-1") do |card|
  prod = products["Acme $25 E-Gift"]
  card.client = acme_client
  card.product = prod
  card.amount = prod.denomination
  card.currency = prod.currency
  card.payout_rate = acme_client.payout_rate
  card.status = "issued"
  card.issued_at = 2.days.ago
end

Card.find_or_create_by!(idempotency_key: "seed-card-2") do |card|
  prod = products["Nova Morning $10"]
  card.client = acme_client
  card.product = prod
  card.amount = prod.denomination
  card.currency = prod.currency
  card.payout_rate = acme_client.payout_rate
  card.status = "issued"
  card.issued_at = 1.day.ago
end

Card.find_or_create_by!(idempotency_key: "seed-card-3") do |card|
  prod = products["Acme $50 Premium Card"]
  card.client = acme_client
  card.product = prod
  card.amount = prod.denomination
  card.currency = prod.currency
  card.payout_rate = acme_client.payout_rate
  card.status = "cancelled"
  card.issued_at = 3.days.ago
  card.cancelled_at = 1.day.ago
end

puts "finish cards"
puts "finish seeding"
