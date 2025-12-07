provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  # Cloudflare becomes the CDN; always point to ALB. Also expose a static assets record when provided.
  cloudflare_origin   = module.alb.alb_dns_name
  primary_record_fqdn = var.cloudflare_record_name == "@" ? var.domain_name : "${var.cloudflare_record_name}.${var.domain_name}"
  static_record_name  = var.cloudflare_record_name == "@" ? "static" : "${var.cloudflare_record_name}-static"
  static_record_fqdn  = local.static_record_name == "@" ? var.domain_name : "${local.static_record_name}.${var.domain_name}"
}

resource "cloudflare_record" "alb_cname" {
  count           = var.use_cloudflare ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = var.cloudflare_record_name
  content         = local.cloudflare_origin
  type            = "CNAME"
  proxied         = true
  ttl             = 1 # Auto
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
  count           = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = local.static_record_name
  content         = var.static_assets_bucket_domain_name
  type            = "CNAME"
  proxied         = true # Enable Cloudflare CDN in front of the S3 bucket
  ttl             = 1    # Auto (required for proxied records)
  allow_overwrite = true
}

resource "cloudflare_ruleset" "static_assets_origin" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "static-assets-origin"
  kind    = "zone"
  phase   = "http_request_origin"

  rules {
    description = "Send static.vkev.me traffic to the S3 bucket hostname"
    expression  = "http.host eq \"${local.static_record_fqdn}\""
    action      = "set_config"

    action_parameters {
      origin {
        host = var.static_assets_bucket_domain_name
        port = 443
      }

      sni {
        value = var.static_assets_bucket_domain_name
      }
    }
  }
}

resource "cloudflare_ruleset" "static_assets_headers" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "static-assets-host-header"
  kind    = "zone"
  phase   = "http_request_transform"

  rules {
    description = "Force Host header to the S3 bucket for static.vkev.me"
    expression  = "http.host eq \"${local.static_record_fqdn}\""
    action      = "rewrite"

    action_parameters {
      headers {
        name      = "Host"
        operation = "set"
        value     = var.static_assets_bucket_domain_name
      }
    }
  }
}

resource "cloudflare_page_rule" "static_assets_cache" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id  = var.cloudflare_zone_id
  target   = "https://${local.static_record_fqdn}/*"
  priority = 1

  actions {
    cache_level    = "cache_everything"
    edge_cache_ttl = 86400 # 1 day
  }
}
