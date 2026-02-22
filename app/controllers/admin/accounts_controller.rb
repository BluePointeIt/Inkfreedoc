# frozen_string_literal: true

module Admin
  class AccountsController < ApplicationController
    before_action :authorize_superadmin!

    def index
      @accounts = Account.order(created_at: :desc)
    end

    def show
      @account = Account.find(params[:id])
    end

    def new
      @account = Account.new
      @user = User.new
    end

    def create
      @account = Account.new(account_params)
      @account.timezone = Accounts.normalize_timezone(@account.timezone)
      @user = @account.users.new(user_params.merge(role: User::ADMIN_ROLE))

      ActiveRecord::Base.transaction do
        if @account.save && @user.save
          @account.encrypted_configs.create!(
            key: EncryptedConfig::ESIGN_CERTS_KEY,
            value: GenerateCertificate.call.transform_values(&:to_pem)
          )

          redirect_to admin_accounts_path, notice: "Account '#{@account.name}' created successfully."
        else
          render :new, status: :unprocessable_content
        end
      end
    end

    def update
      @account = Account.find(params[:id])

      if params[:toggle_status].present?
        if @account.archived_at?
          @account.update!(archived_at: nil)
          redirect_to admin_account_path(@account), notice: "Account '#{@account.name}' enabled."
        else
          @account.update!(archived_at: Time.current)
          redirect_to admin_account_path(@account), notice: "Account '#{@account.name}' disabled."
        end
      else
        redirect_to admin_account_path(@account)
      end
    end

    def destroy
      @account = Account.find(params[:id])

      if @account.id == current_user.account_id
        redirect_to admin_accounts_path, alert: 'Cannot delete your own account.'
        return
      end

      @account.destroy!
      redirect_to admin_accounts_path, notice: "Account '#{@account.name}' deleted."
    end

    private

    def authorize_superadmin!
      authorize! :manage, :superadmin
    end

    def account_params
      params.require(:account).permit(:name, :timezone)
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :password)
    end
  end
end
