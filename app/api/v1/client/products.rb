# frozen_string_literal: true

module V1
  module Client
    class Products < Grape::API
      resource :client do
        before do
          authorize_client!
        end

        resource :products do
          desc "List all products that a client can see in their view (CLI-2, AUTH-7)"
          params do
            optional :page, type: Integer, default: 1, desc: "Page number"
            optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
            optional :query, type: String, desc: "Search by product or brand name"
            optional :currency, type: String, desc: "Filter by currency (e.g. USD)"
          end
          get do
            scope = current_client.products
                                  .kept
                                  .where(state: "active")
                                  .joins(:brand)
                                  .where(brands: { state: "active" })
                                  .includes(:brand)
                                  .order("products.name ASC")

            if params[:query].present?
              q = "%#{params[:query].to_s.strip.downcase}%"
              scope = scope.where("lower(products.name) LIKE :q OR lower(brands.name) LIKE :q", q: q)
            end

            if params[:currency].present?
              scope = scope.where(currency: params[:currency].to_s.strip.upcase)
            end

            total_count = scope.count
            per_page = params[:per_page]
            page = params[:page]
            total_pages = (total_count.to_f / per_page).ceil

            products = scope.offset((page - 1) * per_page).limit(per_page)

            {
              products: products.map do |product|
                {
                  id: product.id,
                  brand_id: product.brand_id,
                  brand_name: product.brand.name,
                  name: product.name,
                  denomination: product.denomination,
                  currency: product.currency,
                  requires_pin: product.requires_pin,
                  custom_fields: product.custom_fields
                }
              end,
              pagination: {
                page: page,
                per_page: per_page,
                total_count: total_count,
                total_pages: total_pages
              }
            }
          end
        end
      end
    end
  end
end
