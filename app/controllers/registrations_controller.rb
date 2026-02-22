# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  skip_authorization_check

  around_action :with_browser_locale

  def new
    @account = Account.new
    @user = User.new
    super
  end

  def create
    @account = Account.new(account_params)
    @account.timezone = Accounts.normalize_timezone(@account.timezone)
    @user = @account.users.new(sign_up_params.merge(role: User::ADMIN_ROLE))

    ActiveRecord::Base.transaction do
      if @account.save && @user.save
        encrypted_configs = [
          { key: EncryptedConfig::ESIGN_CERTS_KEY, value: GenerateCertificate.call.transform_values(&:to_pem) }
        ]
        @account.encrypted_configs.create!(encrypted_configs)

        sign_up(resource_name, @user)
        respond_with @user, location: root_path
      else
        clean_up_passwords @user
        render :new, status: :unprocessable_content
      end
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password)
  end

  def account_params
    params.require(:account).permit(:name, :timezone)
  end

  def with_browser_locale(&)
    I18n.with_locale(I18n.default_locale, &)
  end
end
