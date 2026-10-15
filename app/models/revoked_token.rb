class RevokedToken < ApplicationRecord
  belongs_to :user

  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :expired, -> { where(expires_at: ...Time.current) }

  def self.revoked?(jti)
    exists?(jti: jti)
  end

  # Housekeeping: expired tokens are invalid anyway, so rows can be purged.
  def self.purge_expired!
    expired.delete_all
  end
end
