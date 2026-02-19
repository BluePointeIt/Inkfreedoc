# frozen_string_literal: true

class AddSigningMetadataToSubmitters < ActiveRecord::Migration[8.0]
  def change
    add_column :submitters, :signing_mode, :string, default: 'remote'
    add_column :submitters, :role_label, :string  # "Signer 1", "Witness", "Notary"
    add_column :submitters, :signing_order, :integer, default: 0
    add_column :submitters, :consent_given_at, :datetime
    add_column :submitters, :consent_ip_address, :string
    add_column :submitters, :identity_verified, :boolean, default: false
    add_column :submitters, :identity_method, :string # email, sms_otp, kba
  end
end
