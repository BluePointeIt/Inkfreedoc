# frozen_string_literal: true

class DocumentHash < ApplicationRecord
  belongs_to :submission
  belongs_to :submitter, optional: true
  belongs_to :submission_event, optional: true

  validates :document_hash, presence: true
  validates :hash_algorithm, presence: true

  scope :for_submission, ->(submission) { where(submission:).order(computed_at: :desc) }

  def self.latest_for(submission)
    where(submission:).order(computed_at: :desc).first
  end

  def self.chain_for(submission)
    where(submission:).order(computed_at: :asc)
  end
end
