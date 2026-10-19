# frozen_string_literal: true

module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :audit_create
    after_update :audit_update
  end

  private

  def audit_create
    Audit::Recorder.record!(
      action: "#{self.class.name.underscore}.create",
      record: self,
      after: attributes
    )
  end

  def audit_update
    # saved_changes here come from ActiveRecord, e.g
    # {"user_name": ["old_name", "new_name"], "email": ["old_email", "new_email"]}
    changes = saved_changes.except("updated_at")

    return if changes.empty?

    # before_diff: {"user_name": "old_name", "email": "old_email"}
    # after_diff: {"user_name": "new_name", "email": "new_email"}
    before_diff = changes.transform_values(&:first)
    after_diff  = changes.transform_values(&:last)

    # Because we have 3 kinds of log: toggle state, soft delete, and update
    action = if changes.key?("state")
      "#{self.class.name.underscore}.state_change"
    elsif changes.key?("deleted_at") && deleted_at.present?
      "#{self.class.name.underscore}.delete"
    else
      "#{self.class.name.underscore}.update"
    end

    Audit::Recorder.record!(
      action: action,
      record: self,
      before: before_diff,
      after: after_diff
    )
  end
end
