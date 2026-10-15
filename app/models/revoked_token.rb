class RevokedToken < ApplicationRecord
  belongs_to :user

  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :expired, -> { where(expires_at: ...Time.current) }

  # Check: if table hold the jwt id, not the whole token itself
  # Type: SecureRandom.uuid. We create it whenever we grant a token via login
  # Whenever authenticate, we will invoke this function
  def self.revoked?(jti)
    exists?(jti: jti)
  end

  # Housekeeping: expired tokens are invalid anyway, so rows can be purged.
  # We can do it via daily cronjob later
  def self.purge_expired!
    expired.delete_all
  end
end
