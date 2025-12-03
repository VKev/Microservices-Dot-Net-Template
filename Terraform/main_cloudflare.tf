provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  # Cloudflare becomes the CDN; always point to ALB. Also expose a static assets record when provided.
  cloudflare_origin      = module.alb.alb_dns_name
  static_record_name     = var.cloudflare_record_name == "@" ? "static" : "${var.cloudflare_record_name}-static"
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

resource "cloudflare_record" "static_assets" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.static_record_name
  content = var.static_assets_bucket_domain_name
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
  allow_overwrite = true
}
