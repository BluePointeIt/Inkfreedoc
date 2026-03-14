# frozen_string_literal: true

class TemplateQuickStartController < ApplicationController
  before_action :load_template

  def new
    authorize!(:read, @template)
  end

  def create
    authorize!(:create, Submission)

    template_submitters = @template.submitters.reject { |e| e['invite_by_uuid'].present? }
    first_submitter = template_submitters.first

    submission = Submission.new(
      template: @template,
      account_id: @template.account_id,
      created_by_user: current_user,
      template_submitters: @template.submitters,
      source: :invite,
      submitters_order: 'preserved'
    )

    is_pending = params[:mode] == 'pending'

    submitter = submission.submitters.new(
      uuid: first_submitter['uuid'],
      account_id: @template.account_id,
      email: params[:email].presence,
      name: params[:name],
      ip: request.remote_ip,
      ua: request.user_agent,
      sent_at: is_pending ? nil : Time.current
    )

    template_submitters.drop(1).each do |ts|
      next if submission.submitters.any? { |e| e.uuid == ts['uuid'] }

      submission.submitters.new(
        uuid: ts['uuid'],
        account_id: @template.account_id,
        email: ts['email'].presence,
        name: ts['name'].presence,
        sent_at: is_pending ? nil : Time.current
      )
    end

    submission.save!

    Submissions::AssignDefinedSubmitters.call(submission)

    WebhookUrls.enqueue_events(submission, 'submission.created')
    SearchEntries.enqueue_reindex(submitter)

    if is_pending
      redirect_to pending_submissions_path, notice: I18n.t('document_saved_as_pending', name: params[:name])
    else
      redirect_to submit_form_path(submitter.slug)
    end
  end

  private

  def load_template
    @template = current_account.templates.find(params[:template_id])
  end
end
