# frozen_string_literal: true

module V1
  module Admin
    class Products < Grape::API
      resource :admin do
        before do
          authorize_admin!
        end

        resource :brands do
          route_param :id, type: Integer do
            resource :products do
              desc "List products under a brand (ADM-3, AUTH-6)"
              params do
                optional :page, type: Integer, default: 1, desc: "Page number"
                optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
                optional :state, type: String, values: %w[active inactive], desc: "Filter by product state"
              end
              get do
                brand = Brand.find(params[:id])
                scope = brand.products.kept.order(id: :desc)
                scope = scope.where(state: params[:state]) if params[:state].present?

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
                      name: product.name,
                      denomination: product.denomination,
                      currency: product.currency,
                      requires_pin: product.requires_pin,
                      state: product.state,
                      custom_fields: product.custom_fields,
                      created_at: product.created_at,
                      updated_at: product.updated_at
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

              desc "Create a new product under a brand (ADM-3, LOG-1, LOG-2)"
              params do
                requires :name, type: String, desc: "Product name"
                requires :denomination, type: BigDecimal, desc: "Product denomination (> 0)"
                requires :currency, type: String, desc: "3-letter currency code (e.g. USD)"
                optional :requires_pin, type: Boolean, default: false, desc: "Whether card requires PIN"
                optional :state, type: String, values: %w[active inactive], default: "active", desc: "Product state"
                optional :custom_fields, type: Hash, default: {}, desc: "Up to 5 scalar key-value metadata fields"
              end
              post do
                brand = Brand.find(params[:id])

                product = brand.products.new(
                  name: params[:name],
                  denomination: params[:denomination],
                  currency: params[:currency],
                  requires_pin: params[:requires_pin],
                  state: params[:state],
                  custom_fields: params[:custom_fields] || {}
                )

                if product.save
                  status 201
                  {
                    product: {
                      id: product.id,
                      brand_id: product.brand_id,
                      name: product.name,
                      denomination: product.denomination,
                      currency: product.currency,
                      requires_pin: product.requires_pin,
                      state: product.state,
                      custom_fields: product.custom_fields,
                      created_at: product.created_at,
                      updated_at: product.updated_at
                    }
                  }
                else
                  error!({ error: "Validation Error", details: product.errors.full_messages }, 422)
                end
              end
            end
          end
        end

        resource :products do
          route_param :id, type: Integer do
            desc "Get details of a specific product by ID (ADM-3, AUTH-6)"
            get do
              product = Product.includes(:brand).find(params[:id])

              {
                product: {
                  id: product.id,
                  brand_id: product.brand_id,
                  brand_name: product.brand.name,
                  name: product.name,
                  denomination: product.denomination,
                  currency: product.currency,
                  requires_pin: product.requires_pin,
                  state: product.state,
                  custom_fields: product.custom_fields,
                  is_deleted: product.discarded?,
                  created_at: product.created_at,
                  updated_at: product.updated_at
                }
              }
            end

            desc "Update product details (ADM-3, LOG-1, LOG-2)"
            params do
              optional :name, type: String, desc: "Product name"
              optional :denomination, type: BigDecimal, desc: "Product denomination"
              optional :currency, type: String, desc: "3-letter currency code"
              optional :requires_pin, type: Boolean, desc: "Requires PIN flag"
              optional :custom_fields, type: Hash, desc: "Custom fields metadata"
            end
            patch do
              product = Product.find(params[:id])

              update_params = {}
              update_params[:name] = params[:name] if params[:name].present?
              update_params[:denomination] = params[:denomination] if params[:denomination].present?
              update_params[:currency] = params[:currency] if params[:currency].present?
              update_params[:requires_pin] = params[:requires_pin] unless params[:requires_pin].nil?
              update_params[:custom_fields] = params[:custom_fields] if params.key?(:custom_fields)

              if product.update(update_params)
                {
                  product: {
                    id: product.id,
                    brand_id: product.brand_id,
                    name: product.name,
                    denomination: product.denomination,
                    currency: product.currency,
                    requires_pin: product.requires_pin,
                    state: product.state,
                    custom_fields: product.custom_fields,
                    created_at: product.created_at,
                    updated_at: product.updated_at
                  }
                }
              else
                error!({ error: "Validation Error", details: product.errors.full_messages }, 422)
              end
            end

            desc "Toggle product state between active and inactive (ADM-4, LOG-1, LOG-2)"
            params do
              requires :state, type: String, values: %w[active inactive], desc: "Target product state"
            end
            patch :state do
              product = Product.find(params[:id])

              if product.update(state: params[:state])
                {
                  product: {
                    id: product.id,
                    brand_id: product.brand_id,
                    name: product.name,
                    denomination: product.denomination,
                    currency: product.currency,
                    requires_pin: product.requires_pin,
                    state: product.state,
                    custom_fields: product.custom_fields,
                    created_at: product.created_at,
                    updated_at: product.updated_at
                  }
                }
              else
                error!({ error: "Validation Error", details: product.errors.full_messages }, 422)
              end
            end

            desc "Delete a product (soft delete) if no cards issued (ADM-3, LOG-1, LOG-2)"
            delete do
              product = Product.find(params[:id])

              if product.cards.exists?
                error!({ error: "Conflict", message: "Cannot delete product with existing issued cards" }, 409)
              end

              product.soft_delete!

              { message: "Product deleted successfully" }
            end
          end
        end
      end
    end
  end
end
