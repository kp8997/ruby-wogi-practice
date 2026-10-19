# frozen_string_literal: true

module V1
  module Admin
    class Clients < Grape::API
      resource :admin do
        resource :clients do
          before do
            authorize_admin!
          end

          desc "List all clients with pagination and state filtering (ADM-5, AUTH-6)"
          params do
            optional :page, type: Integer, default: 1, desc: "Page number"
            optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
            optional :state, type: String, values: %w[active inactive], desc: "Filter by user account state"
          end
          get do
            scope = ::Client.includes(:user).order(id: :desc)
            scope = scope.joins(:user).where(users: { state: params[:state] }) if params[:state].present?

            total_count = scope.count
            per_page = params[:per_page]
            page = params[:page]
            total_pages = (total_count.to_f / per_page).ceil

            clients = scope.offset((page - 1) * per_page).limit(per_page)

            {
              clients: clients.map do |client|
                {
                  id: client.id,
                  name: client.name,
                  payout_rate: client.payout_rate,
                  created_at: client.created_at,
                  updated_at: client.updated_at,
                  user: {
                    id: client.user.id,
                    email: client.user.email,
                    role: client.user.role,
                    state: client.user.state
                  }
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

          desc "Create a new client with user credentials and payout rate (AUTH-4, ADM-5, LOG-1, LOG-6)"
          params do
            requires :email, type: String, regexp: URI::MailTo::EMAIL_REGEXP, desc: "Client login email"
            requires :password, type: String, desc: "Client login password"
            requires :name, type: String, desc: "Client business/partner name"
            requires :payout_rate, type: BigDecimal, values: (BigDecimal("0.0")..BigDecimal("100.0")), desc: "Client payout rate (percentage)"
          end
          post do
            client = nil
            user = nil

            ActiveRecord::Base.transaction do
              user = User.new(
                email: params[:email],
                password: params[:password],
                role: "client",
                state: "active"
              )

              unless user.save
                error!({ error: "Validation Error", details: user.errors.full_messages }, 422)
              end

              ::Audit::Recorder.record!(
                action: "user.create",
                record: user,
                after: { id: user.id, email: user.email, role: user.role, state: user.state },
                metadata: { role: "client", email: user.email }
              )

              client = ::Client.new(
                user: user,
                name: params[:name].to_s.strip,
                payout_rate: params[:payout_rate]
              )

              unless client.save
                error!({ error: "Validation Error", details: client.errors.full_messages }, 422)
              end
            end

            status 201
            {
              client: {
                id: client.id,
                name: client.name,
                payout_rate: client.payout_rate,
                created_at: client.created_at,
                updated_at: client.updated_at,
                user: {
                  id: user.id,
                  email: user.email,
                  role: user.role,
                  state: user.state
                }
              }
            }
          end

          route_param :id, type: Integer do
            desc "Get details of a specific client (ADM-5, AUTH-6)"
            get do
              client = ::Client.includes(:user).find(params[:id])

              {
                client: {
                  id: client.id,
                  name: client.name,
                  payout_rate: client.payout_rate,
                  created_at: client.created_at,
                  updated_at: client.updated_at,
                  user: {
                    id: client.user.id,
                    email: client.user.email,
                    role: client.user.role,
                    state: client.user.state
                  }
                }
              }
            end

            desc "Update client details (ADM-5, LOG-1, LOG-2)"
            params do
              optional :name, type: String, desc: "Client business name"
              optional :payout_rate, type: BigDecimal, values: (BigDecimal("0.0")..BigDecimal("100.0")), desc: "Client payout rate"
            end
            patch do
              client = ::Client.includes(:user).find(params[:id])

              update_params = {}
              update_params[:name] = params[:name].to_s.strip if params[:name].present?
              update_params[:payout_rate] = params[:payout_rate] if params[:payout_rate].present?

              if client.update(update_params)
                {
                  client: {
                    id: client.id,
                    name: client.name,
                    payout_rate: client.payout_rate,
                    created_at: client.created_at,
                    updated_at: client.updated_at,
                    user: {
                      id: client.user.id,
                      email: client.user.email,
                      role: client.user.role,
                      state: client.user.state
                    }
                  }
                }
              else
                error!({ error: "Validation Error", details: client.errors.full_messages }, 422)
              end
            end

            desc "Toggle client state between active and inactive (ADM-9, AUTH-8, LOG-1, LOG-2)"
            params do
              requires :state, type: String, values: %w[active inactive], desc: "Target account state"
            end
            patch :state do
              client = ::Client.includes(:user).find(params[:id])
              user = client.user

              old_state = user.state
              new_state = params[:state]

              if old_state != new_state
                user.update!(state: new_state)
                ::Audit::Recorder.record!(
                  action: "user.state_change",
                  record: user,
                  before: { state: old_state },
                  after: { state: new_state },
                  metadata: { client_id: client.id, email: user.email }
                )
              end

              {
                client: {
                  id: client.id,
                  name: client.name,
                  payout_rate: client.payout_rate,
                  user: {
                    id: user.id,
                    email: user.email,
                    role: user.role,
                    state: user.state
                  }
                }
              }
            end

            resource :product_accesses do
              desc "List accessible products for a client (ADM-6, AUTH-6)"
              get do
                client = ::Client.find(params[:id])
                products = client.products.kept.order(:id)

                {
                  product_accesses: products.map do |prod|
                    {
                      product_id: prod.id,
                      brand_id: prod.brand_id,
                      name: prod.name,
                      denomination: prod.denomination,
                      currency: prod.currency,
                      requires_pin: prod.requires_pin,
                      state: prod.state
                    }
                  end
                }
              end

              desc "Grant accessible product to a client (ADM-6, LOG-1, LOG-2)"
              params do
                requires :product_id, type: Integer, desc: "Product ID to grant access to"
              end
              post do
                client = ::Client.find(params[:id])
                product = Product.kept.find(params[:product_id])

                access = ClientProductAccess.find_or_initialize_by(client: client, product: product)
                is_new = access.new_record?

                if is_new
                  access.save!
                  ::Audit::Recorder.record!(
                    action: "client_product_access.create",
                    record: access,
                    after: { client_id: client.id, product_id: product.id },
                    metadata: { client_id: client.id, product_id: product.id }
                  )
                end

                status(is_new ? 201 : 200)
                {
                  product_access: {
                    client_id: client.id,
                    product_id: product.id
                  }
                }
              end

              route_param :product_id, type: Integer do
                desc "Revoke accessible product from a client (ADM-6, LOG-1, LOG-2)"
                delete do
                  client = ::Client.find(params[:id])
                  access = client.client_product_accesses.find_by(product_id: params[:product_id])

                  if access
                    access.destroy!
                    ::Audit::Recorder.record!(
                      action: "client_product_access.delete",
                      record: access,
                      before: { client_id: client.id, product_id: params[:product_id] },
                      metadata: { client_id: client.id, product_id: params[:product_id] }
                    )
                  end

                  { message: "Product access revoked successfully" }
                end
              end
            end
          end
        end
      end
    end
  end
end
