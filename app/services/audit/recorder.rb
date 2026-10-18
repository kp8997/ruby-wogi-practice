module Audit
  class Recorder
    def self.record!(action:, record: nil, before: nil, after: nil, metadata: {})
      clean_before = Sanitizer.clean(before)
      clean_after  = Sanitizer.clean(after)
      clean_meta   = Sanitizer.clean(metadata)

      AuditLog.create!(
        user:          Current.user,
        ip_address:    Current.ip_address,
        user_agent:    Current.user_agent,
        action:        action,
        record_type:   record&.class&.name,
        record_id:     record&.id,
        before_values: clean_before,
        after_values:  clean_after,
        metadata:      clean_meta || {}
      )
    end
  end
end
