class ManifestController < ActionController::Base
  include Rails.application.routes.url_helpers
  skip_before_action :verify_authenticity_token

  def show
    @account = Account.find_by(id: params[:account_id])

    if @account
      render 'manifest', formats: [:json], content_type: 'application/manifest+json'
    else
      render json: default_manifest, content_type: 'application/manifest+json'
    end
  end

  private

  def default_manifest
    {
      name: 'Chatwoot',
      short_name: 'Chatwoot',
      icons: PwaIconGeneratorService::PWA_ICON_SIZES.map do |icon|
        size = icon[:size]
        {
          src: "/android-icon-#{size}x#{size}.png",
          sizes: "#{size}x#{size}",
          type: 'image/png',
          density: icon[:density]
        }
      end,
      start_url: '/',
      display: 'standalone',
      background_color: '#1f93ff',
      theme_color: '#1f93ff'
    }
  end
end
