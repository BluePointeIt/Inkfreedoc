# frozen_string_literal: true

class SendSubmitterInvitationSmsJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])

    return if submitter.completed_at?
    return if submitter.phone.blank?
    return if submitter.submission.archived_at?
    return if submitter.template&.archived_at?
    return unless Accounts.can_send_sms?(submitter.account)

    signing_url = Rails.application.routes.url_helpers.submit_form_url(
      slug: submitter.slug,
      **Docuseal.default_url_options
    )

    body = I18n.t('sms_signing_invitation_message', url: signing_url)

    result = TwilioSms.send_message(
      account: submitter.account,
      to: submitter.phone,
      body: body
    )

    SubmissionEvent.create!(
      submitter: submitter,
      event_type: 'send_sms',
      data: { 'twilio_sid' => result.sid }
    )

    submitter.sent_at ||= Time.current
    submitter.save!
  end
end
