variable "healthchecksio_api_key" {
  description = "Healthchecks.io API Key (read-write)"
  type        = string
  sensitive   = true
}

provider "healthchecksio" {
  api_key = var.healthchecksio_api_key
}

data "healthchecksio_channel" "slack" {
  kind = "slack"
  name = "#healthchecks"
}

resource "healthchecksio_check" "scraper" {
  name     = "scraper"
  schedule = "*/5 10-18 * * *"
  timezone = "America/New_York"
  grace    = 900
  channels = [
    data.healthchecksio_channel.slack.id
  ]
}

