class Api::V1::AccountsController < Api::BaseController
  include AuthHelper
  include CacheKeysHelper

  skip_before_action :authenticate_user!, :set_current_user, :handle_with_exception,
                     only: [:create], raise: false
  before_action :check_signup_enabled, only: [:create]
  before_action :ensure_account_name, only: [:create]
  before_action :validate_captcha, only: [:create]
  before_action :fetch_account, except: [:create]
  before_action :check_authorization, except: [:create]

  rescue_from CustomExceptions::Account::InvalidEmail,
              CustomExceptions::Account::InvalidParams,
              CustomExceptions::Account::UserExists,
              CustomExceptions::Account::UserErrors,
              with: :render_error_response

  def show
    @latest_chatwoot_version = ::Redis::Alfred.get(::Redis::Alfred::LATEST_CHATWOOT_VERSION)
    render 'api/v1/accounts/show', format: :json
  end

  def create
    @user, @account = AccountBuilder.new(
      account_name: account_params[:account_name],
      user_full_name: account_params[:user_full_name],
      email: account_params[:email],
      user_password: account_params[:password],
      locale: account_params[:locale],
      user: current_user
    ).perform
    if @user
      send_auth_headers(@user)
      render 'api/v1/accounts/create', format: :json, locals: { resource: @user }
    else
      render_error_response(CustomExceptions::Account::SignupFailed.new({}))
    end
  end

  def cache_keys
    expires_in 10.seconds, public: false, stale_while_revalidate: 5.minutes
    render json: { cache_keys: cache_keys_for_account }, status: :ok
  end

  def update
    @account.assign_attributes(account_params.slice(:name, :locale, :domain, :support_email, :logo, :website_url, :scraped_data))
    @account.custom_attributes.merge!(custom_attributes_params)
    @account.settings.merge!(settings_params)
    @account.custom_attributes['onboarding_step'] = 'invite_team' if @account.custom_attributes['onboarding_step'] == 'account_update'
    @account.save!
    PwaIconGeneratorJob.perform_later(@account.id) if params[:logo].present? && @account.logo.attached?
  end

  def logo
    @account.logo.attachment.destroy! if @account.logo.attached?
    @account.reload
    render 'api/v1/accounts/show', format: :json
  end

  def scrape
    unless SCRAPER_SERVICE_URL
      render json: { error: 'Scraper service is not configured.' }, status: :service_unavailable
      return
    end

    unless @account.website_url.present?
      render json: { error: 'No website URL saved for this account.' }, status: :unprocessable_entity
      return
    end

    # The worker will call back into our own API using the current user's token.
    api_token = current_user.access_token.token

    payload = {
      account_id:      @account.id,
      website_url:     @account.website_url,
      rails_api_url: request.base_url,
      rails_api_token: api_token
    }.to_json

    uri  = URI("#{SCRAPER_SERVICE_URL}/scrape")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = payload

    begin
      response = http.request(request)
      render json: JSON.parse(response.body), status: response.code.to_i
    rescue StandardError => e
      Rails.logger.error "SCRAPE ERROR: #{e.class} — #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: { error: "Could not reach scraper service: #{e.message}" }, status: :bad_gateway
    end
  end

  def scrape_status
    unless SCRAPER_SERVICE_URL
      render json: { error: 'Scraper service is not configured.' }, status: :service_unavailable
      return
    end

    uri  = URI("#{SCRAPER_SERVICE_URL}/scrape/#{@account.id}/status")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    begin
      response = http.get(uri.path)
      render json: JSON.parse(response.body), status: response.code.to_i
    rescue StandardError => e
      render json: { error: "Could not reach scraper service: #{e.message}" }, status: :bad_gateway
    end
  end

  def update_active_at
    @current_account_user.active_at = Time.now.utc
    @current_account_user.save!
    head :ok
  end

  private

  def ensure_account_name
    return if account_params[:account_name].present?
    return if account_params[:user_full_name].present?

    raise CustomExceptions::Account::InvalidParams.new({})
  end

  def cache_keys_for_account
    {
      label: fetch_value_for_key(params[:id], Label.name.underscore),
      inbox: fetch_value_for_key(params[:id], Inbox.name.underscore),
      team: fetch_value_for_key(params[:id], Team.name.underscore)
    }
  end

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def account_params
    params.permit(:account_name, :email, :name, :password, :locale, :domain, :support_email, :user_full_name, :logo, :website_url, :scraped_data)
  end

  def custom_attributes_params
    params.permit(:industry, :company_size, :timezone)
  end

  def settings_params
    params.permit(*permitted_settings_attributes)
  end

  def permitted_settings_attributes
    [:auto_resolve_after, :auto_resolve_message, :auto_resolve_ignore_waiting, :audio_transcriptions, :auto_resolve_label]
  end

  def check_signup_enabled
    raise ActionController::RoutingError, 'Not Found' if GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false') == 'false'
  end

  def validate_captcha
    raise ActionController::InvalidAuthenticityToken, 'Invalid Captcha' unless ChatwootCaptcha.new(params[:h_captcha_client_response]).valid?
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end

Api::V1::AccountsController.prepend_mod_with('Api::V1::AccountsSettings')
