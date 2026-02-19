# frozen_string_literal: true

module Api
  class SubmissionAuditTrailsController < ApiBaseController
    def show
      submission = current_account.submissions.find(params[:submission_id])

      locations = submission.signing_locations.includes(:submitter)
      events = submission.submission_events.order(:created_at)
      hashes = submission.document_hashes.order(:computed_at)

      render json: {
        document: {
          id: submission.id,
          template_name: submission.template&.name || submission.name,
          created_at: submission.created_at.utc.iso8601,
          completed_at: completed_at(submission),
          status: submission_status(submission)
        },
        integrity: {
          algorithm: 'SHA-256',
          hash_chain_valid: AuditHashService.verify_chain(submission)[:valid],
          hashes: hashes.map do |h|
            {
              event_type: h.event_type,
              document_hash: h.document_hash,
              previous_hash: h.previous_hash,
              computed_at: h.computed_at.iso8601
            }
          end
        },
        signers: submission.submitters.order(:signing_order).map do |submitter|
          location = submitter.signing_locations.order(signed_at_utc: :desc).first

          {
            role: submitter.role_label || 'Signer',
            email: submitter.email,
            name: submitter.name,
            signing_order: submitter.signing_order,
            status: submitter.status,
            signed_at_utc: submitter.completed_at&.utc&.iso8601,
            consent_given_at: submitter.consent_given_at&.iso8601,
            identity_method: submitter.identity_method,
            location: location ? {
              ip_address: location.ip_address,
              device_type: location.device_type,
              operating_system: "#{location.operating_system} #{location.os_version}",
              browser: "#{location.browser_name} #{location.browser_version}",
              city: location.city,
              state: location.state_region,
              country: location.country,
              country_code: location.country_code,
              signing_mode: location.signing_mode,
              gps_coordinates: location.gps_permission_granted ? {
                latitude: location.gps_latitude,
                longitude: location.gps_longitude,
                accuracy_meters: location.gps_accuracy
              } : nil
            } : nil
          }
        end,
        events: events.map do |event|
          {
            timestamp: event.event_timestamp.utc.iso8601,
            event_type: event.event_type,
            submitter_id: event.submitter_id,
            ip_address: event.ip_address,
            event_hash: event.event_hash,
            data: event.data
          }
        end,
        suspicious_activity: SuspiciousActivityDetector.analyze(submission)
      }
    end

    private

    def completed_at(submission)
      last = submission.submitters.select(&:completed_at).max_by(&:completed_at)
      last&.completed_at&.utc&.iso8601
    end

    def submission_status(submission)
      if submission.submitters.all?(&:completed_at?)
        'completed'
      elsif submission.submitters.any?(&:declined_at?)
        'declined'
      elsif submission.expired?
        'expired'
      else
        'pending'
      end
    end
  end
end
