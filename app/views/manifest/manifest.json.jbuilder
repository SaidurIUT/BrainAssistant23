icons = PwaIconGeneratorService::PWA_ICON_SIZES.map do |icon|
  size      = icon[:size]
  density   = icon[:density]
  attach    = @account.public_send(:"pwa_icon_#{size}")

  src = if attach.attached?
          url_for(attach)
        else
          "/android-icon-#{size}x#{size}.png"
        end

  {
    src:     src,
    sizes:   "#{size}x#{size}",
    type:    'image/png',
    density: density
  }
end

json.name        @account.name
json.short_name  @account.name
json.icons       icons
json.start_url   '/'
json.display     'standalone'
json.background_color '#1f93ff'
json.theme_color      '#1f93ff'
