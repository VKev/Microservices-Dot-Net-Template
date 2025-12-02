provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "alb_cname" {
  count   = var.use_cloudflare ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_record_name
  value   = module.alb.alb_dns_name
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto
}
