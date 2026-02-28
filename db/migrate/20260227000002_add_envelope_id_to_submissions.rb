# frozen_string_literal: true

class AddEnvelopeIdToSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_reference :submissions, :envelope, foreign_key: { on_delete: :nullify }, null: true
  end
end
