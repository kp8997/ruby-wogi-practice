# frozen_string_literal: true

module V1
  module Client
    class Cards < Grape::API
      resource :client do
        before do
          authorize_client!
        end

        resource :cards do
          resource :reports do
            desc "Client spending report (CLI-7, REP-3, AUTH-7)"
            params do
              optional :from_date, type: String, desc: "Start date (YYYY-MM-DD or ISO8601)"
              optional :to_date, type: String, desc: "End date (YYYY-MM-DD or ISO8601)"
            end
            get :spending do
              from_time = params[:from_date].present? ? Time.zone.parse(params[:from_date].to_s)&.beginning_of_day : nil
              to_time = params[:to_date].present? ? Time.zone.parse(params[:to_date].to_s)&.end_of_day : nil

              conditions = [ "cards.client_id = :client_id" ]
              bindings = { client_id: current_client.id }

              if from_time
                conditions << "cards.issued_at >= :from_time"
                bindings[:from_time] = from_time
              end

              if to_time
                conditions << "cards.issued_at <= :to_time"
                bindings[:to_time] = to_time
              end

              sql = ActiveRecord::Base.sanitize_sql_array([
                <<-SQL.squish,
                  SELECT
                    COUNT(cards.id) AS total_cards,
                    COALESCE(SUM(cards.amount), 0) AS gross_spend,
                    COALESCE(SUM(cards.payout_amount), 0) AS total_payout,
                    COUNT(CASE WHEN cards.status = 'cancelled' THEN 1 END) AS cancelled_cards,
                    COUNT(CASE WHEN cards.status = 'issued' THEN 1 END) AS active_cards,
                    COALESCE(SUM(CASE WHEN cards.status = 'cancelled' THEN cards.amount ELSE 0 END), 0) AS cancelled_amount,
                    COALESCE(SUM(CASE WHEN cards.status = 'issued' THEN cards.amount ELSE 0 END), 0) AS net_spend
                  FROM cards
                  WHERE #{conditions.join(' AND ')}
                SQL
                bindings
              ])

              result = ActiveRecord::Base.connection.select_one(sql) || {}

              {
                date_range: {
                  from_date: params[:from_date],
                  to_date: params[:to_date]
                },
                report: {
                  total_cards: result["total_cards"].to_i,
                  active_cards: result["active_cards"].to_i,
                  cancelled_cards: result["cancelled_cards"].to_i,
                  gross_spend: BigDecimal(result["gross_spend"].to_s),
                  cancelled_amount: BigDecimal(result["cancelled_amount"].to_s),
                  net_spend: BigDecimal(result["net_spend"].to_s),
                  total_payout_earned: BigDecimal(result["total_payout"].to_s)
                }
              }
            end

            desc "Client cancellation report (CLI-7, REP-3, AUTH-7)"
            params do
              optional :from_date, type: String, desc: "Start date (YYYY-MM-DD or ISO8601)"
              optional :to_date, type: String, desc: "End date (YYYY-MM-DD or ISO8601)"
            end
            get :cancellation do
              from_time = params[:from_date].present? ? Time.zone.parse(params[:from_date].to_s)&.beginning_of_day : nil
              to_time = params[:to_date].present? ? Time.zone.parse(params[:to_date].to_s)&.end_of_day : nil

              scope = current_client.cards.where(status: "cancelled").includes(:product)
              scope = scope.where("cancelled_at >= ?", from_time) if from_time
              scope = scope.where("cancelled_at <= ?", to_time) if to_time

              total_count = scope.count
              total_amount = scope.sum(:amount)

              {
                date_range: {
                  from_date: params[:from_date],
                  to_date: params[:to_date]
                },
                summary: {
                  cancelled_count: total_count,
                  cancelled_amount: BigDecimal(total_amount.to_s)
                },
                cancelled_cards: scope.order(cancelled_at: :desc).limit(100).map do |card|
                  {
                    id: card.id,
                    product_id: card.product_id,
                    product_name: card.product.name,
                    activation_number: "*" * 12 + card.activation_number.last(4),
                    amount: card.amount,
                    currency: card.currency,
                    issued_at: card.issued_at,
                    cancelled_at: card.cancelled_at
                  }
                end
              }
            end
          end

          desc "Retrieve a paginated list of cards owned by the client (CLI-1, AUTH-7)"
          params do
            optional :page, type: Integer, default: 1, desc: "Page number"
            optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
            optional :status, type: String, values: %w[issued cancelled], desc: "Filter by status"
          end
          get do
            scope = current_client.cards.includes(product: :brand).order(issued_at: :desc, id: :desc)
            scope = scope.where(status: params[:status]) if params[:status].present?

            total_count = scope.count
            per_page = params[:per_page]
            page = params[:page]
            total_pages = (total_count.to_f / per_page).ceil

            cards = scope.offset((page - 1) * per_page).limit(per_page)

            {
              cards: cards.map do |card|
                {
                  id: card.id,
                  product_id: card.product_id,
                  product_name: card.product.name,
                  brand_name: card.product.brand.name,
                  activation_number: card.activation_number,
                  amount: card.amount,
                  currency: card.currency,
                  payout_rate: card.payout_rate,
                  payout_amount: card.payout_amount,
                  status: card.status,
                  issued_at: card.issued_at,
                  cancelled_at: card.cancelled_at
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

          desc "Issue a gift card (CLI-3, CLI-4, CLI-5, LOG-4, LOG-6)"
          params do
            requires :product_id, type: Integer, desc: "Product ID to issue card for"
            requires :idempotency_key, type: String, desc: "Unique idempotency key"
            optional :pin, type: String, desc: "Optional PIN code for PIN-enabled cards"
          end
          post do
            # Idempotency issued card check
            existing_card = current_client.cards.includes(product: :brand).find_by(idempotency_key: params[:idempotency_key])
            if existing_card
              status 200
              {
                card: {
                  id: existing_card.id,
                  product_id: existing_card.product_id,
                  product_name: existing_card.product.name,
                  brand_name: existing_card.product.brand.name,
                  activation_number: existing_card.activation_number,
                  amount: existing_card.amount,
                  currency: existing_card.currency,
                  payout_rate: existing_card.payout_rate,
                  payout_amount: existing_card.payout_amount,
                  status: existing_card.status,
                  issued_at: existing_card.issued_at,
                  cancelled_at: existing_card.cancelled_at
                },
                idempotent_replay: true
              }
            else
              # Eligibility client - product checks
              has_access = current_client.client_product_accesses.exists?(product_id: params[:product_id])
              unless has_access
                ::Audit::Recorder.record!(
                  action: "card.issue_refused",
                  metadata: { client_id: current_client.id, product_id: params[:product_id], reason: "product_not_assigned" }
                )
                error!({ error: "Ineligible Product", message: "Product is not assigned to your account" }, 422)
              end

              product = ::Product.kept.includes(:brand).find_by(id: params[:product_id])
              unless product&.active?
                ::Audit::Recorder.record!(
                  action: "card.issue_refused",
                  metadata: { client_id: current_client.id, product_id: params[:product_id], reason: "product_inactive" }
                )
                error!({ error: "Ineligible Product", message: "Product is currently inactive" }, 422)
              end

              unless product.brand.active?
                ::Audit::Recorder.record!(
                  action: "card.issue_refused",
                  metadata: { client_id: current_client.id, product_id: params[:product_id], reason: "brand_inactive" }
                )
                error!({ error: "Ineligible Product", message: "Brand is currently inactive" }, 422)
              end

              # Create card with snapshot payout_rate
              pin_to_assign = params[:pin].presence || (product.requires_pin ? SecureRandom.random_number(1000..9999).to_s : nil)

              card = current_client.cards.new(
                product: product,
                idempotency_key: params[:idempotency_key],
                amount: product.denomination,
                currency: product.currency,
                payout_rate: current_client.payout_rate,
                pin: pin_to_assign,
                status: "issued"
              )

              if card.save
                ::Audit::Recorder.record!(
                  action: "card.issue",
                  record: card,
                  after: {
                    id: card.id,
                    product_id: card.product_id,
                    client_id: card.client_id,
                    amount: card.amount,
                    currency: card.currency,
                    payout_rate: card.payout_rate,
                    payout_amount: card.payout_amount,
                    status: card.status,
                    activation_number: card.activation_number
                  },
                  metadata: { idempotency_key: card.idempotency_key }
                )

                status 201
                response_data = {
                  card: {
                    id: card.id,
                    product_id: card.product_id,
                    product_name: product.name,
                    brand_name: product.brand.name,
                    activation_number: card.activation_number,
                    amount: card.amount,
                    currency: card.currency,
                    payout_rate: card.payout_rate,
                    payout_amount: card.payout_amount,
                    status: card.status,
                    issued_at: card.issued_at
                  }
                }
                response_data[:card][:pin] = pin_to_assign if pin_to_assign.present?
                response_data
              else
                error!({ error: "Validation Error", details: card.errors.full_messages }, 422)
              end
            end
          end

          route_param :id, type: Integer do
            desc "Retrieve a card owned by a client (CLI-1, AUTH-7)"
            get do
              card = current_client.cards.includes(product: :brand).find(params[:id])

              {
                card: {
                  id: card.id,
                  product_id: card.product_id,
                  product_name: card.product.name,
                  brand_name: card.product.brand.name,
                  activation_number: card.activation_number,
                  amount: card.amount,
                  currency: card.currency,
                  payout_rate: card.payout_rate,
                  payout_amount: card.payout_amount,
                  status: card.status,
                  issued_at: card.issued_at,
                  cancelled_at: card.cancelled_at
                }
              }
            end

            desc "Cancel an issued card (CLI-6, LOG-4, AUTH-7)"
            post :cancel do
              card = current_client.cards.find(params[:id])

              if card.cancelled?
                ::Audit::Recorder.record!(
                  action: "card.cancel_refused",
                  record: card,
                  metadata: { reason: "already_cancelled" }
                )
                error!({ error: "Invalid Transition", message: "Card has already been cancelled" }, 422)
              end

              if card.cancel!
                ::Audit::Recorder.record!(
                  action: "card.cancel",
                  record: card,
                  before: { status: "issued" },
                  after: { status: "cancelled", cancelled_at: card.cancelled_at }
                )

                status 200
                {
                  card: {
                    id: card.id,
                    status: card.status,
                    cancelled_at: card.cancelled_at
                  },
                  message: "Card cancelled successfully"
                }
              else
                error!({ error: "Execution Failed", message: "Could not cancel card" }, 422)
              end
            end
          end
        end
      end
    end
  end
end
