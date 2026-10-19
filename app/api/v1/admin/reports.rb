# frozen_string_literal: true

module V1
  module Admin
    class Reports < Grape::API
      resource :admin do
        resource :reports do
          before do
            authorize_admin!
          end

          desc "Brand financial and issuance report (REP-1, ADM-8)"
          params do
            optional :from_date, type: String, desc: "Start date (YYYY-MM-DD or ISO8601)"
            optional :to_date, type: String, desc: "End date (YYYY-MM-DD or ISO8601)"
          end
          get :brands do
            from_time = params[:from_date].present? ? Time.zone.parse(params[:from_date].to_s)&.beginning_of_day : nil
            to_time = params[:to_date].present? ? Time.zone.parse(params[:to_date].to_s)&.end_of_day : nil

            card_conditions = []
            card_conditions << "cards.issued_at >= #{ActiveRecord::Base.connection.quote(from_time)}" if from_time
            card_conditions << "cards.issued_at <= #{ActiveRecord::Base.connection.quote(to_time)}" if to_time
            card_join_sql = "LEFT JOIN cards ON cards.product_id = products.id"
            card_join_sql += " AND #{card_conditions.join(' AND ')}" if card_conditions.any?

            query = <<-SQL.squish
              SELECT
                brands.id AS brand_id,
                brands.name AS brand_name,
                COUNT(cards.id) AS total_cards,
                COALESCE(SUM(cards.amount), 0) AS gross_volume,
                COUNT(CASE WHEN cards.status = 'cancelled' THEN 1 END) AS cancelled_cards,
                COUNT(CASE WHEN cards.status = 'issued' THEN 1 END) AS active_cards,
                COALESCE(SUM(CASE WHEN cards.status = 'issued' THEN cards.amount ELSE 0 END), 0) AS net_volume
              FROM brands
              LEFT JOIN products ON products.brand_id = brands.id
              #{card_join_sql}
              GROUP BY brands.id, brands.name
              ORDER BY gross_volume DESC, brands.name ASC
            SQL

            results = ActiveRecord::Base.connection.select_all(query).to_a

            total_gross = results.sum { |r| BigDecimal(r["gross_volume"].to_s) }
            total_cards = results.sum { |r| r["total_cards"].to_i }
            total_cancelled = results.sum { |r| r["cancelled_cards"].to_i }

            {
              date_range: {
                from_date: params[:from_date],
                to_date: params[:to_date]
              },
              summary: {
                total_gross_volume: total_gross,
                total_cards: total_cards,
                total_cancelled: total_cancelled
              },
              brands: results.map do |row|
                {
                  brand_id: row["brand_id"].to_i,
                  brand_name: row["brand_name"],
                  total_cards: row["total_cards"].to_i,
                  gross_volume: BigDecimal(row["gross_volume"].to_s),
                  active_cards: row["active_cards"].to_i,
                  cancelled_cards: row["cancelled_cards"].to_i,
                  net_volume: BigDecimal(row["net_volume"].to_s)
                }
              end
            }
          end

          desc "Client spend and payout report (REP-2, ADM-8)"
          params do
            optional :from_date, type: String, desc: "Start date (YYYY-MM-DD or ISO8601)"
            optional :to_date, type: String, desc: "End date (YYYY-MM-DD or ISO8601)"
          end
          get :clients do
            from_time = params[:from_date].present? ? Time.zone.parse(params[:from_date].to_s)&.beginning_of_day : nil
            to_time = params[:to_date].present? ? Time.zone.parse(params[:to_date].to_s)&.end_of_day : nil

            card_conditions = []
            card_conditions << "cards.issued_at >= #{ActiveRecord::Base.connection.quote(from_time)}" if from_time
            card_conditions << "cards.issued_at <= #{ActiveRecord::Base.connection.quote(to_time)}" if to_time
            card_join_sql = "LEFT JOIN cards ON cards.client_id = clients.id"
            card_join_sql += " AND #{card_conditions.join(' AND ')}" if card_conditions.any?

            query = <<-SQL.squish
              SELECT
                clients.id AS client_id,
                clients.name AS client_name,
                users.email AS client_email,
                COUNT(cards.id) AS total_cards,
                COALESCE(SUM(cards.amount), 0) AS gross_spend,
                COALESCE(SUM(cards.payout_amount), 0) AS total_payout,
                COUNT(CASE WHEN cards.status = 'cancelled' THEN 1 END) AS cancelled_cards,
                COUNT(CASE WHEN cards.status = 'issued' THEN 1 END) AS active_cards
              FROM clients
              JOIN users ON users.id = clients.user_id
              #{card_join_sql}
              GROUP BY clients.id, clients.name, users.email
              ORDER BY gross_spend DESC, clients.name ASC
            SQL

            results = ActiveRecord::Base.connection.select_all(query).to_a

            total_spend = results.sum { |r| BigDecimal(r["gross_spend"].to_s) }
            total_payout = results.sum { |r| BigDecimal(r["total_payout"].to_s) }
            total_cards = results.sum { |r| r["total_cards"].to_i }
            total_cancelled = results.sum { |r| r["cancelled_cards"].to_i }

            {
              date_range: {
                from_date: params[:from_date],
                to_date: params[:to_date]
              },
              summary: {
                total_gross_spend: total_spend,
                total_payout: total_payout,
                total_cards: total_cards,
                total_cancelled: total_cancelled
              },
              clients: results.map do |row|
                {
                  client_id: row["client_id"].to_i,
                  client_name: row["client_name"],
                  client_email: row["client_email"],
                  total_cards: row["total_cards"].to_i,
                  gross_spend: BigDecimal(row["gross_spend"].to_s),
                  total_payout: BigDecimal(row["total_payout"].to_s),
                  active_cards: row["active_cards"].to_i,
                  cancelled_cards: row["cancelled_cards"].to_i
                }
              end
            }
          end
        end
      end
    end
  end
end
