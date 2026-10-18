terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    uptimekuma = {
      source  = "breml/uptimekuma"
      version = "~> 0.4"
    }
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = "~> 2.3.0"
    }
  }
}

provider "cloudflare" {
  # email pulled from $CLOUDFLARE_EMAIL
  # token pulled from $CLOUDFLARE_API_TOKEN
}

variable "zone_id" {
  default = "e89f43ddf3cecee098364bb8ab3f9675"
}

variable "domain" {
  default = "gordon-pn.com"
}

# --- Previously Managed CNAME Records ---

resource "cloudflare_record" "swarmpit" {
  zone_id = var.zone_id
  name    = "swarmpit"
  content = var.domain
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "portainer" {
  zone_id = var.zone_id
  name    = "portainer"
  content = var.domain
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "jenkins" {
  zone_id = var.zone_id
  name    = "jenkins"
  content = var.domain
  type    = "CNAME"
  proxied = true
}

# --- Cloudflare Pages & Web Applications ---

resource "cloudflare_record" "apex" {
  zone_id = var.zone_id
  name    = var.domain
  content = "portfolio-4tf.pages.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  content = "portfolio-4tf.pages.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "gym" {
  zone_id = var.zone_id
  name    = "gym"
  content = "gym-calculator.pages.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "notes" {
  zone_id = var.zone_id
  name    = "notes"
  content = "notes-1op.pages.dev"
  type    = "CNAME"
  proxied = true
}

# --- Cloudflare Tunnels (Ingress) ---

resource "cloudflare_record" "ntfy" {
  zone_id = var.zone_id
  name    = "ntfy"
  content = "35e86fee-93ab-4954-a01c-d40026bd42ca.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "ssh" {
  zone_id = var.zone_id
  name    = "ssh"
  content = "3f08a512-41c7-4448-831c-742e41a33afb.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# --- SendGrid Email Deliverability ---

resource "cloudflare_record" "sendgrid_em7255" {
  zone_id = var.zone_id
  name    = "em7255"
  content = "u16081710.wl211.sendgrid.net"
  type    = "CNAME"
  proxied = false
}

resource "cloudflare_record" "sendgrid_dkim_1" {
  zone_id = var.zone_id
  name    = "s1._domainkey"
  content = "s1.domainkey.u16081710.wl211.sendgrid.net"
  type    = "CNAME"
  proxied = false
}

resource "cloudflare_record" "sendgrid_dkim_2" {
  zone_id = var.zone_id
  name    = "s2._domainkey"
  content = "s2.domainkey.u16081710.wl211.sendgrid.net"
  type    = "CNAME"
  proxied = false
}

# --- ImprovMX Inbound Routing & SPF ---

resource "cloudflare_record" "improvmx_mx_1" {
  zone_id  = var.zone_id
  name     = var.domain
  content  = "mx1.improvmx.com"
  type     = "MX"
  priority = 10
}

resource "cloudflare_record" "improvmx_mx_2" {
  zone_id  = var.zone_id
  name     = var.domain
  content  = "mx2.improvmx.com"
  type     = "MX"
  priority = 20
}

resource "cloudflare_record" "improvmx_spf" {
  zone_id = var.zone_id
  name    = var.domain
  content = "v=spf1 include:spf.improvmx.com ~all"
  type    = "TXT"
}
