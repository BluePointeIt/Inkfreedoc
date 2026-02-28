# frozen_string_literal: true

class CreateEnvelopes < ActiveRecord::Migration[8.0]
  def change
    create_table :envelopes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by_user, foreign_key: { to_table: :users }, null: false
      t.string :name
      t.string :source, null: false, default: 'invite'
      t.boolean :send_email, null: false, default: true
      t.datetime :completed_at
      t.datetime :archived_at

      t.timestamps
    end
  end
end
