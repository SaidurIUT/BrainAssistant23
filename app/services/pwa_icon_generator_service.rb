class PwaIconGeneratorService
  PWA_ICON_SIZES = [
    { size: 36, density: '0.75' },
    { size: 48, density: '1.0' },
    { size: 72, density: '1.5' },
    { size: 96, density: '2.0' },
    { size: 144, density: '3.0' },
    { size: 192, density: '4.0' }
  ].freeze

  def initialize(account)
    @account = account
    @converter_url = ENV.fetch('IMAGE_CONVERTER_URL', 'http://localhost:8099')
  end

  def generate!
    return unless @account.logo.attached?

    logo_blob = @account.logo.blob
    logo_io = StringIO.new(logo_blob.download)

    PWA_ICON_SIZES.each do |icon|
      size = icon[:size]
      converted = call_converter(logo_io, size)
      next if converted.nil?

      attachment_name = :"pwa_icon_#{size}"
      # Purge existing before attaching new
      @account.public_send(attachment_name).purge if @account.public_send(attachment_name).attached?

      @account.public_send(attachment_name).attach(
        io: StringIO.new(converted),
        filename: "android-icon-#{size}x#{size}.png",
        content_type: 'image/png'
      )

      logo_io.rewind
    end
  rescue StandardError => e
    Rails.logger.error("[PwaIconGeneratorService] Failed for account #{@account.id}: #{e.message}")
  end

  private

  def call_converter(logo_io, size)
    logo_io.rewind
    uri = URI.parse("#{@converter_url}/convert?format=png&width=#{size}&height=#{size}&keep_aspect=false")

    request = Net::HTTP::Post.new(uri)
    form_data = [['file', logo_io, { filename: 'logo.png', content_type: 'image/png' }]]
    request.set_form(form_data, 'multipart/form-data')

    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 15) do |http|
      http.request(request)
    end

    return response.body if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn("[PwaIconGeneratorService] Converter returned #{response.code} for size #{size}")
    nil
  rescue StandardError => e
    Rails.logger.error("[PwaIconGeneratorService] Converter call failed for size #{size}: #{e.message}")
    nil
  end
end
