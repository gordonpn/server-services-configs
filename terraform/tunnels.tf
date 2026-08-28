variable "account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
  default     = ""
}

resource "random_id" "vps_tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_tunnel" "vps_shield" {
  account_id = var.account_id
  name       = "vps-shield-tunnel"
  secret     = random_id.vps_tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "vps_shield_config" {
  account_id = var.account_id
  tunnel_id  = cloudflare_tunnel.vps_shield.id

  config {
    ingress_rule {
      hostname = "test.${var.domain}"
      service  = "http://100.88.170.93:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "test" {
  zone_id         = var.zone_id
  name            = "test"
  value           = "${cloudflare_tunnel.vps_shield.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

output "vps_tunnel_token" {
  description = "Tunnel token for VPS cloudflared service"
  value       = cloudflare_tunnel.vps_shield.tunnel_token
  sensitive   = true
}
