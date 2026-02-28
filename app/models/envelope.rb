# frozen_string_literal: true

class Envelope < ApplicationRecord
  belongs_to :account
  belongs_to :created_by_user, class_name: 'User'

  has_many :submissions, dependent: :nullify
  has_many :submitters, through: :submissions

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :pending, -> { where(completed_at: nil) }

  def update_status!
    return if completed_at.present?

    all_completed = submitters.where(completed_at: nil).none?

    update!(completed_at: Time.current) if all_completed
  end

  def status
    if completed_at?
      'completed'
    else
      'pending'
    end
  end
end
