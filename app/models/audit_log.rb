class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :for_action, ->(action) { where(action: action) if action.present? }
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :for_record, ->(type, id) { where(record_type: type, record_id: id) if type.present? && id.present? }
  scope :in_date_range, ->(from, to) { where(created_at: from..to) if from.present? && to.present? }

  def readonly?
    persisted?
  end

  before_destroy do
    raise ActiveRecord::ReadOnlyRecord, "AuditLog cannot be deleted."
  end
end
