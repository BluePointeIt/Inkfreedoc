# frozen_string_literal: true

module TwilioSms
  module_function

  def send_message(account:, to:, body:)
    config = load_config(account)

    raise 'SMS is not configured' if config.blank?

    require 'twilio-ruby'

    client = Twilio::REST::Client.new(config['account_sid'], config['auth_token'])

    client.messages.create(
      from: config['from_number'],
      to: to,
      body: body
    )
  end

  def configured?(account)
    config = load_config(account)

    config.present? &&
      config['account_sid'].present? &&
      config['auth_token'].present? &&
      config['from_number'].present?
  end

  def load_config(account)
    EncryptedConfig.find_by(account: account, key: EncryptedConfig::SMS_CONFIGS_KEY)&.value
  end
end
