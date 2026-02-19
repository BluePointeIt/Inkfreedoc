# frozen_string_literal: true

class SigningMetadataCapture
  class << self
    # Enhance an already-created submission event with location/device/audit metadata
    # Called after SubmissionEvents.create_with_tracking_data in the signing flow
    def enhance_event(event:, submitter:, request:, gps_params: {})
      ip_address  = extract_client_ip(request)
      user_agent  = request.user_agent
      geo_data    = GeoIpService.lookup(ip_address)
      device_data = DeviceDetectionService.detect(user_agent)
      signing_mode = SigningModeDetector.detect(
        submission:        submitter.submission,
        current_submitter: submitter,
        ip_address:
      )

      # Get previous event hash for chaining
      previous_event = submitter.submission.submission_events
                                .where.not(event_hash: nil)
                                .where.not(id: event.id)
                                .order(created_at: :desc).first

      # Compute event hash for the chain
      event_hash = AuditHashService.hash_event(
        event_data: {
          event_type:    event.event_type,
          submitter_id:  submitter.id,
          submission_id: submitter.submission_id,
          timestamp:     event.created_at,
          ip_address:
        },
        previous_hash: previous_event&.event_hash
      )

      # Enhance the existing event with hash chain data
      event.update_columns(
        ip_address:,
        user_agent:,
        event_hash:,
        previous_event_hash: previous_event&.event_hash
      )

      # Store signing location
      SigningLocation.create!(
        submitter:,
        submission_event: event,
        ip_address:,
        signed_at_utc:       Time.current.utc,
        local_time_string:   gps_params[:local_time],
        local_timezone_name: gps_params[:local_timezone],
        signing_mode:,
        **device_data.slice(:device_type, :operating_system, :os_version,
                            :browser_name, :browser_version, :user_agent_raw),
        **geo_data.slice(:city, :state_region, :country, :country_code,
                         :postal_code, :timezone),
        ip_latitude:          geo_data[:latitude],
        ip_longitude:         geo_data[:longitude],
        gps_latitude:         gps_params[:gps_latitude].presence&.to_f,
        gps_longitude:        gps_params[:gps_longitude].presence&.to_f,
        gps_accuracy:         gps_params[:gps_accuracy].presence&.to_f,
        gps_permission_granted: gps_params[:gps_permission_granted] == 'true'
      )

      # Update submitter with signing mode
      submitter.update_columns(signing_mode:)

      event
    end

    # Standalone capture (used by kiosk mode or other flows that create their own events)
    def capture(submitter:, request:, gps_params: {})
      event = SubmissionEvents.create_with_tracking_data(submitter, 'complete_form', request)
      enhance_event(event:, submitter:, request:, gps_params:)
    end

    def extract_client_ip(request)
      forwarded = request.headers['X-Forwarded-For']
      if forwarded.present?
        forwarded.split(',').first.strip
      else
        request.headers['X-Real-IP'] || request.remote_ip
      end
    end
  end
end
