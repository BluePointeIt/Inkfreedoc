# frozen_string_literal: true

class CreateDocumentHashes < ActiveRecord::Migration[8.0]
  def change
    create_table :document_hashes do |t|
      t.bigint :submission_id, null: false
      t.bigint :submitter_id
      t.bigint :submission_event_id

      t.string :hash_algorithm, null: false, default: 'SHA-256'
      t.string :document_hash,  null: false # hex-encoded SHA-256
      t.string :previous_hash   # chain link to prior hash
      t.string :event_type      # created, signed, completed, voided
      t.jsonb  :metadata, default: {}

      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :document_hashes, :submission_id
    add_index :document_hashes, :submitter_id
    add_index :document_hashes, :document_hash
    add_index :document_hashes, [:submission_id, :computed_at]

    add_foreign_key :document_hashes, :submissions
    add_foreign_key :document_hashes, :submitters
  end
end
