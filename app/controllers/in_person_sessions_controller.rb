# frozen_string_literal: true

class InPersonSessionsController < ApplicationController
  layout 'form'

  skip_before_action :authenticate_user!, only: %i[show advance complete_signer]
  skip_authorization_check only: %i[show advance complete_signer]

  before_action :authenticate_user!, only: %i[create]
  before_action :load_session, only: %i[show advance complete_signer]

  # POST /in_person_sessions - Admin starts a kiosk signing session
  def create
    submission = current_account.submissions.find(params[:submission_id])

    session = SigningSession.create!(
      submission:,
      account:            current_account,
      session_type:       params[:session_type] || 'in_person_kiosk',
      ip_address:         request.remote_ip,
      initiated_by:       current_user.email,
      signer_order:       submission.submitters.order(:signing_order).pluck(:id),
      started_at:         Time.current,
      expires_at:         Time.current + 4.hours
    )

    redirect_to kiosk_sign_path(token: session.session_token)
  end

  # GET /sign/kiosk/:token - Kiosk signing page
  def show
    if @signing_session.expired?
      return render :expired
    end

    @current_submitter = @signing_session.current_signer

    if @current_submitter.nil?
      @signing_session.update!(completed_at: Time.current) if @signing_session.completed_at.nil?
      return render :all_complete
    end

    @submission = @signing_session.submission
    @total_signers = @submission.submitters.count
    @current_index = @submission.submitters.order(:signing_order)
                                .index(@current_submitter)&.+(1) || 1
  end

  # POST /sign/kiosk/:token/advance - Move to next signer
  def advance
    if @signing_session.expired?
      return render :expired
    end

    # Clear session-specific data between signers for privacy
    reset_session

    redirect_to kiosk_sign_path(token: @signing_session.session_token)
  end

  # POST /sign/kiosk/:token/complete - Mark current signer done (called by form)
  def complete_signer
    if @signing_session.expired?
      return render json: { error: 'Session expired' }, status: :unprocessable_content
    end

    if @signing_session.all_signed?
      @signing_session.update!(completed_at: Time.current) if @signing_session.completed_at.nil?
    end

    head :ok
  end

  private

  def load_session
    @signing_session = SigningSession.find_by!(session_token: params[:token])
  end
end
