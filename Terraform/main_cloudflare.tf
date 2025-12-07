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
  proxied = true
  ttl     = 1 # Auto
  allow_overwrite = true
}

# Route `/s3/*` on the primary hostname directly to the S3 bucket (strip the /s3 prefix).
resource "cloudflare_ruleset" "primary_s3_origin" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "Primary host S3 origin for /s3"
  phase   = "http_request_origin"
  kind    = "zone"

  rules {
    description = "Send /s3/* on ${local.primary_record_fqdn} to S3 origin"
    expression  = "(http.host eq \"${local.primary_record_fqdn}\") and (starts_with(http.request.uri.path, \"/s3\"))"
    action      = "route"

    action_parameters {
      host_header = var.static_assets_bucket_domain_name
      origin {
        host = var.static_assets_bucket_domain_name
      }
    }
  }
}

# Rewrite /s3/* -> /* so S3 sees the correct object key.
resource "cloudflare_ruleset" "primary_s3_rewrite" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "Primary host S3 path rewrite"
  phase   = "http_request_transform"
  kind    = "zone"

  rules {
    description = "Rewrite /s3 prefix away for S3 origin"
    expression  = "(http.host eq \"${local.primary_record_fqdn}\") and (starts_with(http.request.uri.path, \"/s3\"))"
    action      = "rewrite"

    action_parameters {
      uri {
        path {
          # Remove leading /s3 or /s3/ while preserving the rest of the path.
          expression = "regex_replace(http.request.uri.path, \"^/s3/?\", \"/\")"
        }
      }
    }
  }
}

# Cache `/s3/*` responses on the primary hostname.
resource "cloudflare_ruleset" "primary_s3_cache" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "Primary host S3 cache settings"
  phase   = "http_request_cache_settings"
  kind    = "zone"

  rules {
    description = "Cache S3 assets served via /s3 on ${local.primary_record_fqdn}"
    expression  = "(http.host eq \"${local.primary_record_fqdn}\") and (starts_with(http.request.uri.path, \"/s3\"))"
    action      = "set_cache_settings"

    action_parameters {
      cache = true

      edge_ttl {
        mode    = "override_origin"
        default = 3600
      }

      browser_ttl {
        mode = "respect_origin"
      }
    }
  }
}

# Ensure Cloudflare talks to S3 using the bucket hostname (Host header + origin),
# otherwise S3 rejects the request and caching never occurs.
resource "cloudflare_ruleset" "static_assets_origin" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "Static assets origin override"
  phase   = "http_request_origin"
  kind    = "zone"

  rules {
    description = "Send ${local.static_record_fqdn} traffic to S3 bucket origin"
    expression  = "(http.host eq \"${local.static_record_fqdn}\")"
    action      = "route"

    action_parameters {
      host_header = var.static_assets_bucket_domain_name
      origin {
        host = var.static_assets_bucket_domain_name
      }
    }
  }

  depends_on = [cloudflare_record.static_assets]
}

# Explicitly enable edge caching for the static assets hostname.
resource "cloudflare_ruleset" "static_assets_cache" {
  count   = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "Static assets cache settings"
  phase   = "http_request_cache_settings"
  kind    = "zone"

  rules {
    description = "Cache S3 assets served via ${local.static_record_fqdn}"
    expression  = "(http.host eq \"${local.static_record_fqdn}\")"
    action      = "set_cache_settings"

    action_parameters {
      cache = true

      edge_ttl {
        mode    = "override_origin"
        default = 3600
      }

      browser_ttl {
        mode = "respect_origin"
      }
    }
  }

  depends_on = [cloudflare_record.static_assets]
}
