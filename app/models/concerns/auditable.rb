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
    changes = saved_changes.except("updated_at")
    return if changes.empty?
    before_diff = changes.transform_values(&:first)
    after_diff  = changes.transform_values(&:last)

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
