# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'shoulda/matchers'
require 'database_cleaner/active_record'

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Require all files in spec/support
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods (create, build, build_stubbed)
  config.include FactoryBot::Syntax::Methods

  # Include API helpers in request specs
  config.include ApiHelpers, type: :request

  # Reset Current attributes and clean state after each test
  config.after(:each) do
    Current.reset
  end
end
