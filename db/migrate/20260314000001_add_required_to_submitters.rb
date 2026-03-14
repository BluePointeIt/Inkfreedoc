# frozen_string_literal: true

class AddRequiredToSubmitters < ActiveRecord::Migration[8.0]
  def change
    add_column :submitters, :required, :boolean, default: true, null: false
  end
end
