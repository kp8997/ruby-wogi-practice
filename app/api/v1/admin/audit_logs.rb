# frozen_string_literal: true

module V1
  module Admin
    class AuditLogs < Grape::API
      resource :admin do
        resource :audit_logs do
          before do
            authorize_admin!
          end

          desc "List and filter immutable audit logs (ADM-7, LOG-5, LOG-6)"
          params do
            optional :page, type: Integer, default: 1, desc: "Page number"
            optional :per_page, type: Integer, default: 20, values: 1..100, desc: "Items per page"
            optional :user_id, type: Integer, desc: "Filter by acting user ID"
            optional :action, type: String, desc: "Filter by action name"
            optional :record_type, type: String, desc: "Filter by target record type"
            optional :record_id, type: Integer, desc: "Filter by target record ID"
            optional :from_date, type: String, desc: "Filter events from date"
            optional :to_date, type: String, desc: "Filter events to date"
          end
          get do
            scope = AuditLog.includes(:user).recent

            scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
            scope = scope.where(action: params[:action]) if params[:action].present?
            scope = scope.where(record_type: params[:record_type]) if params[:record_type].present?
            scope = scope.where(record_id: params[:record_id]) if params[:record_id].present?

            if params[:from_date].present?
              from_time = Time.zone.parse(params[:from_date].to_s)&.beginning_of_day
              scope = scope.where("audit_logs.created_at >= ?", from_time) if from_time
            end

            if params[:to_date].present?
              to_time = Time.zone.parse(params[:to_date].to_s)&.end_of_day
              scope = scope.where("audit_logs.created_at <= ?", to_time) if to_time
            end

            total_count = scope.count
            per_page = params[:per_page]
            page = params[:page]
            total_pages = (total_count.to_f / per_page).ceil

            logs = scope.offset((page - 1) * per_page).limit(per_page)

            {
              audit_logs: logs.map do |log|
                {
                  id: log.id,
                  action: log.action,
                  user: log.user ? { id: log.user.id, email: log.user.email, role: log.user.role } : nil,
                  record_type: log.record_type,
                  record_id: log.record_id,
                  before_values: log.before_values,
                  after_values: log.after_values,
                  metadata: log.metadata,
                  ip_address: log.ip_address,
                  user_agent: log.user_agent,
                  created_at: log.created_at
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
