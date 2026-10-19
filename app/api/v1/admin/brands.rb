# frozen_string_literal: true

module V1
  module Admin
    class Brands < Grape::API
      resource :admin do
        resource :brands do
          before do
            authorize_admin!
          end

          desc "List all brands with pagination and state filtering (ADM-2, AUTH-6)"
          params do
            optional :page, type: Integer, default: 1, desc: "Page number"
            optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
            optional :state, type: String, values: %w[active inactive], desc: "Filter by brand state"
          end
          get do
            scope = Brand.order(id: :desc)
            scope = scope.where(state: params[:state]) if params[:state].present?

            total_count = scope.count
            per_page = params[:per_page]
            page = params[:page]
            total_pages = (total_count.to_f / per_page).ceil

            brands = scope.offset((page - 1) * per_page).limit(per_page)

            {
              brands: brands.map do |brand|
                {
                  id: brand.id,
                  name: brand.name,
                  state: brand.state,
                  custom_fields: brand.custom_fields,
                  created_at: brand.created_at,
                  updated_at: brand.updated_at
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

          desc "Create a new brand (ADM-2, LOG-1, LOG-2)"
          params do
            requires :name, type: String, desc: "Brand name"
            optional :state, type: String, values: %w[active inactive], default: "active", desc: "Brand state"
            optional :custom_fields, type: Hash, default: {}, desc: "Up to 5 scalar key-value metadata fields"
          end
          post do
            brand = Brand.new(
              name: params[:name],
              state: params[:state],
              custom_fields: params[:custom_fields] || {}
            )

            if brand.save
              status 201
              {
                brand: {
                  id: brand.id,
                  name: brand.name,
                  state: brand.state,
                  custom_fields: brand.custom_fields,
                  created_at: brand.created_at,
                  updated_at: brand.updated_at
                }
              }
            else
              error!({ error: "Validation Error", details: brand.errors.full_messages }, 422)
            end
          end

          route_param :id, type: Integer do
            desc "Get details of a specific brand by ID (ADM-2, AUTH-6)"
            get do
              brand = Brand.find(params[:id])

              {
                brand: {
                  id: brand.id,
                  name: brand.name,
                  state: brand.state,
                  custom_fields: brand.custom_fields,
                  products_count: brand.products.count,
                  created_at: brand.created_at,
                  updated_at: brand.updated_at
                }
              }
            end

            desc "Update brand details (ADM-2, LOG-1, LOG-2)"
            params do
              optional :name, type: String, desc: "Brand name"
              optional :custom_fields, type: Hash, desc: "Custom fields metadata"
            end
            patch do
              brand = Brand.find(params[:id])

              update_params = {}
              update_params[:name] = params[:name] if params[:name].present?
              update_params[:custom_fields] = params[:custom_fields] if params.key?(:custom_fields)

              if brand.update(update_params)
                {
                  brand: {
                    id: brand.id,
                    name: brand.name,
                    state: brand.state,
                    custom_fields: brand.custom_fields,
                    created_at: brand.created_at,
                    updated_at: brand.updated_at
                  }
                }
              else
                error!({ error: "Validation Error", details: brand.errors.full_messages }, 422)
              end
            end

            desc "Toggle brand state between active and inactive (ADM-4, LOG-1, LOG-2)"
            params do
              requires :state, type: String, values: %w[active inactive], desc: "Target brand state"
            end
            patch :state do
              brand = Brand.find(params[:id])

              if brand.update(state: params[:state])
                {
                  brand: {
                    id: brand.id,
                    name: brand.name,
                    state: brand.state,
                    custom_fields: brand.custom_fields,
                    created_at: brand.created_at,
                    updated_at: brand.updated_at
                  }
                }
              else
                error!({ error: "Validation Error", details: brand.errors.full_messages }, 422)
              end
            end
          end
        end
      end
    end
  end
end
