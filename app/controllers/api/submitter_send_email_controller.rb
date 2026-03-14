# frozen_string_literal: true

module Api
  class SubmitterSendEmailController < ApiBaseController
    load_and_authorize_resource :submitter

    def create
      return render json: { error: 'Submitter has already completed' }, status: :unprocessable_content if @submitter.completed_at?

      SendSubmitterInvitationEmailJob.perform_async('submitter_id' => @submitter.id)

      @submitter.sent_at ||= Time.current
      @submitter.save!

      render json: { status: 'email_sent', submitter_id: @submitter.id }
    end
  end
end
