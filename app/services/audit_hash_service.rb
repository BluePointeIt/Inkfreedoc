# frozen_string_literal: true

class AuditHashService
  ALGORITHM = 'SHA-256'

  class << self
    # Hash a document (PDF binary content)
    def hash_document(file_content)
      Digest::SHA256.hexdigest(file_content)
    end

    # Hash an audit event and chain it to the previous event
    def hash_event(event_data:, previous_hash: nil)
      payload = {
        event_type:    event_data[:event_type],
        submitter_id:  event_data[:submitter_id],
        submission_id: event_data[:submission_id],
        timestamp:     event_data[:timestamp]&.iso8601,
        ip_address:    event_data[:ip_address],
        previous_hash:
      }.to_json

      Digest::SHA256.hexdigest(payload)
    end

    # Verify the entire hash chain for a submission
    def verify_chain(submission)
      events = submission.submission_events
                         .where.not(event_hash: nil)
                         .order(:created_at)
      previous_hash = nil

      events.each do |event|
        expected = hash_event(
          event_data: {
            event_type:    event.event_type,
            submitter_id:  event.submitter_id,
            submission_id: event.submission_id,
            timestamp:     event.created_at,
            ip_address:    event.ip_address
          },
          previous_hash:
        )

        return { valid: false, broken_at: event.id } if expected != event.event_hash

        previous_hash = event.event_hash
      end

      { valid: true, events_verified: events.size }
    end

    # Store a document hash in the chain
    def record_document_hash(submission:, submitter: nil, event_type:, file_content: nil, file_hash: nil)
      hash_value = file_hash || (file_content ? hash_document(file_content) : nil)
      return unless hash_value

      previous = DocumentHash.latest_for(submission)

      DocumentHash.create!(
        submission:,
        submitter:,
        hash_algorithm: ALGORITHM,
        document_hash:  hash_value,
        previous_hash:  previous&.document_hash,
        event_type:,
        computed_at:    Time.current
      )
    end
  end
end
