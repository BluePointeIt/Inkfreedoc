# frozen_string_literal: true

class SigningLocation < ApplicationRecord
  belongs_to :submitter
  belongs_to :submission_event, optional: true

  has_one :submission, through: :submitter

  validates :ip_address, presence: true
  validates :signing_mode, inclusion: {
    in: %w[remote in_person same_network same_device_session]
  }

  scope :by_country, ->(code) { where(country_code: code) }
  scope :by_device,  ->(type) { where(device_type: type) }
  scope :by_mode,    ->(mode) { where(signing_mode: mode) }
  scope :remote,     -> { where(signing_mode: 'remote') }
  scope :in_person,  -> { where(signing_mode: 'in_person') }
  scope :with_gps,   -> { where(gps_permission_granted: true) }

  before_create :set_ip_address_hash

  private

  def set_ip_address_hash
    self.ip_address_hash = Digest::SHA256.hexdigest(ip_address) if ip_address.present?
  end
end
