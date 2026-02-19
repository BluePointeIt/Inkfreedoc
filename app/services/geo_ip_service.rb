# frozen_string_literal: true

class GeoIpService
  DB_PATH = Rails.root.join('db', 'geoip', 'GeoLite2-City.mmdb').to_s

  class << self
    def lookup(ip_address)
      return empty_result if ip_address.blank? || private_ip?(ip_address)
      return empty_result unless File.exist?(DB_PATH)

      require 'maxmind/geoip2'

      reader = MaxMind::GeoIP2::Reader.new(database: DB_PATH)
      record = reader.city(ip_address)

      {
        city:         record&.city&.name,
        state_region: record&.most_specific_subdivision&.name,
        country:      record&.country&.name,
        country_code: record&.country&.iso_code,
        postal_code:  record&.postal&.code,
        latitude:     record&.location&.latitude,
        longitude:    record&.location&.longitude,
        timezone:     record&.location&.time_zone
      }
    rescue MaxMind::GeoIP2::AddressNotFoundError
      empty_result
    rescue StandardError => e
      Rails.logger.error("GeoIP lookup failed for #{ip_address}: #{e.message}")
      empty_result
    end

    def available?
      File.exist?(DB_PATH)
    end

    private

    def private_ip?(ip)
      addr = IPAddr.new(ip)
      addr.private? || addr.loopback? || addr.link_local?
    rescue IPAddr::InvalidAddressError
      true
    end

    def empty_result
      {
        city: nil, state_region: nil, country: nil,
        country_code: nil, postal_code: nil,
        latitude: nil, longitude: nil, timezone: nil
      }
    end
  end
end
