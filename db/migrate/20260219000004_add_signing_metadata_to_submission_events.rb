# frozen_string_literal: true

class AddSigningMetadataToSubmissionEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :submission_events, :ip_address, :string
    add_column :submission_events, :user_agent, :string
    add_column :submission_events, :document_hash, :string
    add_column :submission_events, :event_hash, :string   # hash of event itself
    add_column :submission_events, :previous_event_hash, :string # chain

    add_index :submission_events, :ip_address
    add_index :submission_events, :event_hash
  end
end
