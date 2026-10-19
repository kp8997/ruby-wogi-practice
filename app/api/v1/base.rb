# frozen_string_literal: true

module V1
  class Base < Grape::API
    version "v1", using: :path

    # Helper
    helpers V1::Helpers::AuthHelpers

    # Interceptor
    before do
      Current.ip_address = request.ip
      Current.user_agent = request.user_agent
      Current.user       = current_user
    end

    # Validation Error catch
    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ error: "Validation Error", details: e.message }, 400)
    end

    # Active Record Error catch
    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: "Not Found", message: e.message }, 404)
    end

    # Mount resource endpoints
    mount V1::Ping
    mount V1::Auth
  end
end
