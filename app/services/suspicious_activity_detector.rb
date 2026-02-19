# frozen_string_literal: true

class SuspiciousActivityDetector
  class << self
    def analyze(submission)
      flags = []

      locations = SigningLocation
        .joins(:submitter)
        .where(submitters: { submission_id: submission.id })

      flags.concat(check_same_ip(locations))
      flags.concat(check_rapid_signing(submission))
      flags
    end

    def flagged_submissions(account)
      # Find submissions where multiple distinct signers share an IP
      # but were not in an explicit in-person session
      submission_ids = SigningLocation
        .joins(submitter: :submission)
        .where(submissions: { account_id: account.id })
        .where.not(signing_mode: %w[in_person same_device_session])
        .group('submitters.submission_id, signing_locations.ip_address')
        .having('COUNT(DISTINCT signing_locations.submitter_id) > 1')
        .pluck('submitters.submission_id')
        .uniq

      Submission.where(id: submission_ids)
    end

    private

    def check_same_ip(locations)
      flags = []
      grouped = locations.group_by(&:ip_address)

      grouped.each do |ip, locs|
        unique_signers = locs.map(&:submitter_id).uniq.size
        next unless unique_signers > 1

        signing_modes = locs.map(&:signing_mode).uniq

        # Only flag if NOT explicitly in-person
        unless signing_modes.include?('in_person') || signing_modes.include?('same_device_session')
          flags << {
            type: 'same_ip_different_signers',
            severity: 'warning',
            details: "#{unique_signers} signers from IP #{ip}",
            ip:
          }
        end
      end

      flags
    end

    def check_rapid_signing(submission)
      flags = []
      events = submission.submission_events.where(event_type: %w[view_form complete_form start_form])

      submission.submitters.where.not(completed_at: nil).find_each do |submitter|
        view_event = events.find { |e| e.submitter_id == submitter.id && e.event_type.in?(%w[view_form start_form]) }
        sign_event = events.find { |e| e.submitter_id == submitter.id && e.event_type == 'complete_form' }

        next unless view_event && sign_event

        duration = sign_event.created_at - view_event.created_at

        if duration < 30.seconds
          flags << {
            type: 'rapid_signing',
            severity: 'high',
            details: "#{submitter.email || submitter.name} signed in #{duration.to_i}s after viewing",
            submitter_id: submitter.id
          }
        end
      end

      flags
    end
  end
end
