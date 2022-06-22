terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
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

resource "cloudflare_record" "swarmpit" {
  zone_id = var.zone_id
  name    = "swarmpit"
  value   = var.domain
  type    = "CNAME"
  proxied = true
}
