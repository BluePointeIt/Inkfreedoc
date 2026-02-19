# frozen_string_literal: true

class SigningSession < ApplicationRecord
  belongs_to :submission
  belongs_to :account

  validates :session_token, presence: true, uniqueness: true
  validates :session_type, inclusion: {
    in: %w[remote in_person_kiosk in_person_shared]
  }

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  before_validation :generate_session_token, on: :create

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def current_signer
    submission.submitters
              .where(completed_at: nil)
              .order(:signing_order)
              .first
  end

  def next_signer_after(submitter)
    submission.submitters
              .where(completed_at: nil)
              .where.not(id: submitter.id)
              .order(:signing_order)
              .first
  end

  def all_signed?
    submission.submitters.where(completed_at: nil).none?
  end

  def in_person?
    session_type.in?(%w[in_person_kiosk in_person_shared])
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.urlsafe_base64(32)
  end
end
