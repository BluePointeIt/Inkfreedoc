# frozen_string_literal: true

class CreateSigningLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :signing_locations do |t|
      t.bigint :submitter_id, null: false
      t.bigint :submission_event_id

      # Network info
      t.string :ip_address, null: false
      t.string :ip_address_hash # SHA-256 for GDPR pseudonymization

      # Device info
      t.string :device_type        # desktop, mobile, tablet
      t.string :operating_system
      t.string :os_version
      t.string :browser_name
      t.string :browser_version
      t.text   :user_agent_raw

      # Geolocation (derived from IP via MaxMind)
      t.string  :city
      t.string  :state_region
      t.string  :country
      t.string  :country_code
      t.string  :postal_code
      t.decimal :ip_latitude,  precision: 10, scale: 7
      t.decimal :ip_longitude, precision: 10, scale: 7
      t.string  :timezone

      # GPS (browser Geolocation API, if user grants permission)
      t.decimal :gps_latitude,  precision: 10, scale: 7
      t.decimal :gps_longitude, precision: 10, scale: 7
      t.decimal :gps_accuracy   # meters
      t.boolean :gps_permission_granted, default: false

      # Signing context
      t.string :signing_mode, null: false, default: 'remote'
      # Values: remote, in_person, same_network, same_device_session

      # Timestamps
      t.datetime :signed_at_utc, null: false
      t.string   :local_time_string   # e.g., 2026-02-18T14:30:00-05:00
      t.string   :local_timezone_name # e.g., America/New_York

      t.timestamps
    end

    add_index :signing_locations, :submitter_id
    add_index :signing_locations, :submission_event_id
    add_index :signing_locations, :ip_address
    add_index :signing_locations, :signing_mode
    add_index :signing_locations, :country_code
    add_index :signing_locations, :device_type
    add_index :signing_locations, [:ip_address, :submitter_id]

    add_foreign_key :signing_locations, :submitters
    add_foreign_key :signing_locations, :submission_events
  end
end
