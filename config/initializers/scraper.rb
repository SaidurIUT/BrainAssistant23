# config/initializers/scraper.rb
#
# Reads the scraper microservice base URL from the environment.

SCRAPER_SERVICE_URL = ENV.fetch('SCRAPER_SERVICE_URL', nil)
