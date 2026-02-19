# frozen_string_literal: true

class DeviceDetectionService
  class << self
    def detect(user_agent_string)
      return empty_result if user_agent_string.blank?

      require 'browser'

      browser = Browser.new(user_agent_string)

      {
        device_type:      detect_device_type(browser),
        operating_system: browser.platform.name,
        os_version:       browser.platform.version.to_s,
        browser_name:     browser.name,
        browser_version:  browser.version,
        user_agent_raw:   user_agent_string
      }
    end

    private

    def detect_device_type(browser)
      if browser.device.tablet?
        'tablet'
      elsif browser.device.mobile?
        'mobile'
      else
        'desktop'
      end
    end

    def empty_result
      {
        device_type: 'unknown',
        operating_system: nil,
        os_version: nil,
        browser_name: nil,
        browser_version: nil,
        user_agent_raw: nil
      }
    end
  end
end
