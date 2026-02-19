# frozen_string_literal: true

class SigningModeDetector
  class << self
    def detect(submission:, current_submitter:, ip_address:)
      # Check if this is an explicit kiosk/in-person session
      signing_session = SigningSession.find_by(
        submission_id: submission.id,
        session_type: %w[in_person_kiosk in_person_shared]
      )

      return 'in_person' if signing_session.present?

      other_locations = SigningLocation
        .joins(:submitter)
        .where(submitters: { submission_id: submission.id })
        .where.not(submitter_id: current_submitter.id)

      # Check if same device session (same IP + recent time window)
      same_device = other_locations.where(
        ip_address:
      ).where('signed_at_utc > ?', 30.minutes.ago).exists?

      return 'same_device_session' if same_device

      # Check if same network (same IP but different time window)
      same_ip = other_locations.where(ip_address:).exists?

      return 'same_network' if same_ip

      'remote'
    end
  end
end
