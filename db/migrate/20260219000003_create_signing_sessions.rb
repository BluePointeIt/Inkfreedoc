# frozen_string_literal: true

class CreateSigningSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :signing_sessions do |t|
      t.bigint :submission_id, null: false
      t.bigint :account_id,    null: false

      t.string   :session_token,  null: false
      t.string   :session_type,   null: false, default: 'remote'
      # Values: remote, in_person_kiosk, in_person_shared

      t.string   :device_fingerprint
      t.string   :ip_address
      t.string   :initiated_by # admin/staff email who started the session
      t.jsonb    :signer_order, default: []  # ordered list of submitter IDs

      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :signing_sessions, :submission_id
    add_index :signing_sessions, :account_id
    add_index :signing_sessions, :session_token, unique: true

    add_foreign_key :signing_sessions, :submissions
    add_foreign_key :signing_sessions, :accounts
  end
end
