provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "selected" {
  count   = var.use_cloudflare ? 1 : 0
  zone_id = var.cloudflare_zone_id
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

resource "cloudflare_ruleset" "static_assets_cache" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "static-assets-cache"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules {
    description = "Cache S3 assets served via static.vkev.me"
    expression  = "http.host eq \"${local.static_record_fqdn}\""
    action      = "set_cache_settings"

    action_parameters {
      cache = true

      edge_ttl {
        mode    = "override_origin"
        default = 86400 # 1 day
      }

      browser_ttl {
        mode = "respect_origin"
      }

      respect_strong_etags = true
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

# Worker to preserve the S3 Host header for presigned URLs while keeping caching at the edge.
resource "cloudflare_workers_script" "static_assets_proxy" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  account_id         = data.cloudflare_zone.selected[0].account_id
  name               = "${var.project_name}-static-proxy"
  module             = true
  compatibility_date = "2025-01-01"
  content            = <<-EOF
    export default {
      async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const bucketHost = "${var.static_assets_bucket_domain_name}";

        // Only allow safe methods to the bucket.
        if (request.method !== "GET" && request.method !== "HEAD") {
          return new Response("Method Not Allowed", { status: 405 });
        }

        const originUrl = `https://$${bucketHost}$${url.pathname}$${url.search}`;

        const headers = new Headers(request.headers);
        headers.set("Host", bucketHost);

        const init = {
          method: request.method,
          headers,
          redirect: "follow",
          cf: { cacheEverything: true, cacheTtl: 86400 }
        };

        return fetch(originUrl, init);
      }
    };
  EOF
}

resource "cloudflare_workers_route" "static_assets_proxy" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  pattern     = "${local.static_record_fqdn}/*"
  script_name = cloudflare_workers_script.static_assets_proxy[0].name
}
