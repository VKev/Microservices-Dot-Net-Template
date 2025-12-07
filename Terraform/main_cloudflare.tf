provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  # Cloudflare becomes the CDN; always point to ALB. Also expose a static assets record when provided.
  cloudflare_origin      = module.alb.alb_dns_name
  primary_record_fqdn    = var.cloudflare_record_name == "@" ? var.domain_name : "${var.cloudflare_record_name}.${var.domain_name}"
  static_record_name     = var.cloudflare_record_name == "@" ? "static" : "${var.cloudflare_record_name}-static"
  static_record_fqdn     = local.static_record_name == "@" ? var.domain_name : "${local.static_record_name}.${var.domain_name}"
}

resource "cloudflare_record" "alb_cname" {
  count   = var.use_cloudflare ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_record_name
  content = local.cloudflare_origin
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
  allow_overwrite = true
}

resource "cloudflare_zone_settings_override" "zone_ssl_mode" {
  count   = var.use_cloudflare ? 1 : 0
  zone_id = var.cloudflare_zone_id

  settings {
    # Use Strict only when an ACM cert is attached to the ALB; otherwise keep Flexible.
    ssl = local.effective_certificate_arn != null ? "strict" : "flexible"

    # Force Cloudflare edge to redirect HTTP -> HTTPS for the entire zone.
    always_use_https = "on"
  }
}

resource "cloudflare_record" "static_assets" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.static_record_name
  content = var.static_assets_bucket_domain_name
  type    = "CNAME"
  proxied = false # DNS-only so S3 sees the bucket hostname on free plan
  ttl     = 300
  allow_overwrite = true
}
