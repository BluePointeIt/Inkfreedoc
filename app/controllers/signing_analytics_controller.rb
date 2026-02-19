# frozen_string_literal: true

class SigningAnalyticsController < ApplicationController
  before_action :authenticate_user!
  authorize_resource :submission, parent: false

  def index
    @stats = {
      total_submissions:   current_account.submissions.count,
      completed_today:     current_account.submissions
                             .joins(:submitters)
                             .where('submitters.completed_at >= ?', Time.current.beginning_of_day)
                             .distinct.count,
      in_person_signings:  account_signing_locations.where(signing_mode: 'in_person').count,
      remote_signings:     account_signing_locations.where(signing_mode: 'remote').count,
      same_network:        account_signing_locations.where(signing_mode: 'same_network').count,
      same_device:         account_signing_locations.where(signing_mode: 'same_device_session').count
    }

    @recent_signings = account_signing_locations
      .order(signed_at_utc: :desc)
      .limit(50)
      .includes(submitter: :submission)

    @device_breakdown = account_signing_locations
      .group(:device_type).count

    @country_breakdown = account_signing_locations
      .where.not(country: nil)
      .group(:country).count
      .sort_by { |_k, v| -v }.first(10)

    @flagged_count = SuspiciousActivityDetector.flagged_submissions(current_account).count
  end

  def flagged
    @flagged_submissions = SuspiciousActivityDetector.flagged_submissions(current_account)
                                                      .order(created_at: :desc)
                                                      .limit(50)

    @flags_by_submission = {}
    @flagged_submissions.each do |submission|
      @flags_by_submission[submission.id] = SuspiciousActivityDetector.analyze(submission)
    end
  end

  def export
    locations = account_signing_locations

    # Apply filters
    locations = locations.where(ip_address: params[:ip]) if params[:ip].present?
    locations = locations.where(device_type: params[:device]) if params[:device].present?
    locations = locations.where(country_code: params[:country]) if params[:country].present?
    locations = locations.where(signing_mode: params[:mode]) if params[:mode].present?

    if params[:from].present? && params[:to].present?
      locations = locations.where(signed_at_utc: Time.parse(params[:from])..Time.parse(params[:to]))
    end

    respond_to do |format|
      format.csv do
        send_data generate_csv(locations.includes(submitter: :submission)),
                  filename: "signing_report_#{Date.current}.csv",
                  type: 'text/csv'
      end
      format.json do
        render json: locations.as_json(include: { submitter: { only: %i[email name role_label] } })
      end
    end
  end

  def audit_trail
    submission = current_account.submissions.find(params[:submission_id])
    @events = submission.submission_events.order(:created_at)
    @locations = submission.signing_locations.includes(:submitter)
    @hashes = submission.document_hashes.order(:computed_at)
    @chain_status = AuditHashService.verify_chain(submission)
    @flags = SuspiciousActivityDetector.analyze(submission)

    render json: {
      submission_id: submission.id,
      integrity: @chain_status,
      flags: @flags,
      events: @events.map { |e| serialize_event(e) },
      locations: @locations.map { |l| serialize_location(l) },
      hashes: @hashes.map { |h| serialize_hash(h) }
    }
  end

  private

  def account_signing_locations
    SigningLocation
      .joins(submitter: :submission)
      .where(submissions: { account_id: current_account.id })
  end

  def generate_csv(locations)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << %w[submission_id signer_email signer_name role signed_at_utc ip_address
                device_type browser os city state country signing_mode
                gps_latitude gps_longitude gps_accuracy]

      locations.find_each do |loc|
        csv << [
          loc.submitter.submission_id,
          loc.submitter.email,
          loc.submitter.name,
          loc.submitter.role_label,
          loc.signed_at_utc&.iso8601,
          loc.ip_address,
          loc.device_type,
          "#{loc.browser_name} #{loc.browser_version}",
          "#{loc.operating_system} #{loc.os_version}",
          loc.city,
          loc.state_region,
          loc.country,
          loc.signing_mode,
          loc.gps_latitude,
          loc.gps_longitude,
          loc.gps_accuracy
        ]
      end
    end
  end

  def serialize_event(event)
    {
      id: event.id,
      type: event.event_type,
      timestamp: event.event_timestamp&.iso8601,
      submitter_id: event.submitter_id,
      ip_address: event.ip_address,
      event_hash: event.event_hash,
      data: event.data
    }
  end

  def serialize_location(location)
    {
      submitter_email: location.submitter.email,
      role: location.submitter.role_label,
      ip_address: location.ip_address,
      device_type: location.device_type,
      browser: "#{location.browser_name} #{location.browser_version}",
      os: "#{location.operating_system} #{location.os_version}",
      city: location.city,
      state: location.state_region,
      country: location.country,
      signing_mode: location.signing_mode,
      signed_at: location.signed_at_utc&.iso8601,
      gps: location.gps_permission_granted ? {
        lat: location.gps_latitude,
        lng: location.gps_longitude,
        accuracy: location.gps_accuracy
      } : nil
    }
  end

  def serialize_hash(hash)
    {
      event_type: hash.event_type,
      document_hash: hash.document_hash,
      previous_hash: hash.previous_hash,
      computed_at: hash.computed_at&.iso8601
    }
  end
end
