variable "kuma_endpoint" {
  description = "Uptime Kuma API endpoint"
  type        = string
  default     = "https://p01--uptime-kuma--m5z2j5q8x7zn.code.run"
}

variable "kuma_username" {
  description = "Uptime Kuma username"
  type        = string
  default     = "gordonpn"
}

variable "kuma_password" {
  description = "Uptime Kuma password"
  type        = string
  sensitive   = true
}

variable "kuma_slack_webhook_url" {
  description = "Slack webhook URL for Uptime Kuma notifications"
  type        = string
  sensitive   = true
}

provider "uptimekuma" {
  endpoint = var.kuma_endpoint
  username = var.kuma_username
  password = var.kuma_password
}

resource "uptimekuma_notification_slack" "slack" {
  name         = "Slack"
  webhook_url  = var.kuma_slack_webhook_url
  is_active    = true
  is_default   = true
  rich_message = true
}

resource "uptimekuma_monitor_push" "master_host" {
  name             = "master-host"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "master_k3s" {
  name             = "master-k3s"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "master_swarm" {
  name             = "master-swarm"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "racknerd_host" {
  name             = "racknerd-host"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "racknerd_swarm" {
  name             = "racknerd-swarm"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "racknerd_k3s" {
  name             = "racknerd-k3s"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

resource "uptimekuma_monitor_push" "home_ssh_reverse_tunnel" {
  name             = "Home SSH Reverse Tunnel"
  interval         = 120
  retry_interval   = 120
  resend_interval  = 1
  max_retries      = 2
  active           = true
  upside_down      = false
  notification_ids = [uptimekuma_notification_slack.slack.id]
}

output "kuma_push_tokens" {
  description = "Push tokens for Uptime Kuma push monitors"
  sensitive   = true
  value = {
    master_host             = uptimekuma_monitor_push.master_host.push_token
    master_k3s              = uptimekuma_monitor_push.master_k3s.push_token
    master_swarm            = uptimekuma_monitor_push.master_swarm.push_token
    racknerd_host           = uptimekuma_monitor_push.racknerd_host.push_token
    racknerd_swarm          = uptimekuma_monitor_push.racknerd_swarm.push_token
    racknerd_k3s            = uptimekuma_monitor_push.racknerd_k3s.push_token
    home_ssh_reverse_tunnel = uptimekuma_monitor_push.home_ssh_reverse_tunnel.push_token
  }
}
