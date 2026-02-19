# frozen_string_literal: true

module Api
  class SubmissionIntegrityController < ApiBaseController
    def show
      submission = current_account.submissions.find(params[:submission_id])

      chain_result = AuditHashService.verify_chain(submission)
      hashes = submission.document_hashes.order(:computed_at)

      render json: {
        submission_id: submission.id,
        hash_algorithm: 'SHA-256',
        chain_valid: chain_result[:valid],
        events_verified: chain_result[:events_verified],
        broken_at_event_id: chain_result[:broken_at],
        document_hashes: hashes.map do |h|
          {
            event_type: h.event_type,
            hash: h.document_hash,
            previous: h.previous_hash,
            computed_at: h.computed_at.iso8601,
            submitter_id: h.submitter_id
          }
        end
      }
    end
  end
end
