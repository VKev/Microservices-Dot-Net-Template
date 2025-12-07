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

resource "cloudflare_worker_script" "static_assets" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  account_id = data.cloudflare_zone.selected[0].account_id
  name       = "${var.project_name}-static-proxy"
  content    = <<-EOF
    export default {
      async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const bucketHost = "${var.static_assets_bucket_domain_name}";

        if (request.method !== "GET" && request.method !== "HEAD") {
          return new Response("Method Not Allowed", { status: 405 });
        }

        // Build origin URL to S3 bucket, preserving path/query.
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

resource "cloudflare_worker_route" "static_assets" {
  count = var.use_cloudflare && var.static_assets_bucket_domain_name != "" ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  pattern     = "${local.static_record_fqdn}/*"
  script_name = cloudflare_worker_script.static_assets[0].name
}
