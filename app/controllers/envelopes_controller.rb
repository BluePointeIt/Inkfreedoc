# frozen_string_literal: true

class EnvelopesController < ApplicationController
  load_and_authorize_resource :envelope, only: %i[show]

  before_action only: %i[new create] do
    authorize!(:create, Envelope)
  end

  def new
    @templates = current_account.templates.accessible_by(current_ability)
                                .where(archived_at: nil)
                                .order(:name)
  end

  def create
    template_ids = Array(params[:template_ids]).map(&:to_i).reject(&:zero?)

    if template_ids.blank?
      redirect_to new_envelope_path, alert: I18n.t('please_select_at_least_one_template')
      return
    end

    templates = current_account.templates.accessible_by(current_ability)
                               .where(id: template_ids, archived_at: nil)

    source = params[:source] == 'local' ? 'local' : 'invite'
    send_email = params[:send_email] == '1' && source != 'local'

    envelope = Envelope.create!(
      account: current_account,
      created_by_user: current_user,
      name: params[:envelope_name].presence,
      source: source,
      send_email: send_email
    )

    all_submissions = []

    templates.each do |template|
      submissions =
        if source == 'local'
          build_local_submissions(template, envelope, params[:recipient_name])
        else
          build_email_submissions(template, envelope, params[:emails])
        end

      all_submissions.concat(submissions)
    end

    if send_email && all_submissions.present?
      Submissions.send_signature_requests(all_submissions)
    end

    SearchEntries.enqueue_reindex(all_submissions) if all_submissions.present?

    redirect_to envelope_path(envelope), notice: I18n.t('envelope_sent_successfully')
  rescue Submissions::CreateFromSubmitters::BaseError => e
    redirect_to new_envelope_path, alert: e.message
  end

  def show
    @envelope_submissions = @envelope.submissions.preload(:template, submitters: :documents_attachments)
  end

  private

  def build_email_submissions(template, envelope, emails)
    submissions = Submissions.create_from_emails(
      template: template,
      user: current_user,
      source: :invite,
      mark_as_sent: envelope.send_email,
      emails: emails,
      params: { 'send_completed_email' => true }
    )

    submissions.each { |s| s.update!(envelope: envelope) }

    submissions
  end

  def build_local_submissions(template, envelope, recipient_name)
    submissions_attrs = [{
      submitters: template.submitters.map do |ts|
        { role: ts['name'], name: recipient_name.presence }
      end
    }]

    submissions = Submissions.create_from_submitters(
      template: template,
      user: current_user,
      source: :link,
      submitters_order: 'preserved',
      submissions_attrs: submissions_attrs,
      params: { 'send_email' => false }
    )

    submissions.each { |s| s.update!(envelope: envelope) }

    submissions
  end
end
