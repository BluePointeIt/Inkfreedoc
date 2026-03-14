# frozen_string_literal: true

class PendingSubmissionsController < ApplicationController
  ITEMS_PER_PAGE = 12

  authorize_resource :submission, only: :index

  def index
    submissions = current_account.submissions
                                 .joins(:submitters)
                                 .where(submitters: { completed_at: nil, declined_at: nil })
                                 .where(archived_at: nil)
                                 .where.not(template_id: nil)
                                 .preload(:template, :audit_trail_attachment, submitters: :start_form_submission_events)
                                 .distinct
                                 .order(created_at: :desc)

    @pagy, @submissions = pagy(submissions, items: ITEMS_PER_PAGE)

    @submissions.each { |submission| sync_missing_parties(submission) }
  end

  def edit
    authorize!(:create, Submission)

    @submitter = current_account.submitters.find(params[:id])
    @submission = @submitter.submission
  end

  def update
    authorize!(:create, Submission)

    @submitter = current_account.submitters.find(params[:id])
    @submitter.update!(submitter_params)

    redirect_to pending_submissions_path, notice: I18n.t('document_updated')
  end

  def send_form
    authorize!(:create, Submission)

    @submission = current_account.submissions.find(params[:id])
    sync_missing_parties(@submission)
    @submitters = @submission.submitters.order(:created_at)
    @template_submitters = @submission.template&.submitters || []
  end

  def send_signing
    authorize!(:create, Submission)

    if params[:submitter_emails].present?
      submission = current_account.submissions.find(params[:id])
      sync_missing_parties(submission)

      included_ids = (params[:send_to] || {}).select { |_, v| v == '1' }.keys.map(&:to_i)

      params[:submitter_emails].each do |submitter_id, email|
        next unless included_ids.include?(submitter_id.to_i)

        submitter = submission.submitters.find_by(id: submitter_id)
        submitter&.update!(email: email.strip) if email.present?
      end

      submitters_with_email = submission.submitters.where(id: included_ids)
                                        .where.not(email: [nil, ''])
                                        .where(completed_at: nil)

      if submitters_with_email.empty?
        return redirect_to pending_submissions_path, alert: I18n.t('email_is_required')
      end

      submitters_with_email.update_all(sent_at: Time.current)
      Submissions.send_signature_requests([submission])
      redirect_to pending_submissions_path, notice: I18n.t('signature_request_sent')
    else
      @submitter = current_account.submitters.find(params[:id])
      submission = @submitter.submission
      sync_missing_parties(submission)

      if params[:send_method] == 'email'
        submitters_with_email = submission.submitters.where.not(email: [nil, ''])
                                          .where(completed_at: nil)

        if submitters_with_email.empty?
          return redirect_to pending_submissions_path, alert: I18n.t('email_is_required')
        end

        submitters_with_email.update_all(sent_at: Time.current)
        Submissions.send_signature_requests([submission])
        redirect_to pending_submissions_path, notice: I18n.t('signature_request_sent')
      else
        @submitter.update!(sent_at: Time.current)
        redirect_to submit_form_path(@submitter.slug)
      end
    end
  end

  private

  def sync_missing_parties(submission)
    template = submission.template
    return unless template

    template_submitters = template.submitters.reject { |e| e['invite_by_uuid'].present? }
    existing_uuids = submission.submitters.pluck(:uuid)

    new_submitters = template_submitters.reject { |ts| existing_uuids.include?(ts['uuid']) }
    return if new_submitters.empty?

    new_submitters.each do |ts|
      submission.submitters.create!(
        uuid: ts['uuid'],
        account_id: submission.account_id,
        email: ts['email'].presence,
        name: ts['name'].presence
      )
    end

    updates = { template_submitters: template.submitters }
    updates[:template_fields] = nil if submission.template_fields.present?
    submission.update!(updates)

    submission.submitters.reload
  end

  def submitter_params
    permitted = params.require(:submitter).permit(:name, :email, :phone, metadata: %i[day month daily_rate])

    if permitted[:metadata].present?
      permitted[:metadata] = (@submitter.metadata || {}).merge(permitted[:metadata].to_h)
    end

    permitted
  end
end
