# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

project_name = "vkev2406-infrastructure-khanghv2406"

aws_region = "us-east-1"

region = "us-east-1"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.3.0/24",
  "10.0.4.0/24"
]

instance_type = "t3.micro"

associate_public_ip = true

enable_auto_scaling = false

use_eks = true

enable_service_connect = true

rds = {
  user = {
    db_names = [
      "defaultdb",
      "n8ndb"
    ]
    username          = "<REDACTED>"
    engine_version    = "18.1"
    instance_class    = "db.t3.micro"
    password          = "<REDACTED>"
    allocated_storage = 5
  }
  guest = {
    db_names = [
      "defaultdb"
    ]
    username          = "<REDACTED>"
    engine_version    = "18.1"
    instance_class    = "db.t3.micro"
    password          = "<REDACTED>"
    allocated_storage = 5
  }
}

dockerhub_pull_through_prefix = "dockerhub"

dockerhub_pull_through_registry = "registry-1.docker.io"

dockerhub_username = "<REDACTED>"

dockerhub_password = "<REDACTED>"

use_cloudfront_https = true

cloudfront_enable_caching = false

cloudfront_enable_logging = false

cloudfront_logging_bucket = "vkev2406-infrastructure-khanghv2406-us-east-1-terraform-state"

cloudfront_logging_prefix = "cloudfront-logs/"

cloudfront_logging_include_cookies = false

certificate_arn = null

enable_https_redirect = true

use_cloudflare = true

cloudflare_api_token = "<REDACTED>"

cloudflare_account_id = "<REDACTED>"

cloudflare_zone_id = "<REDACTED>"

domain_name = "vkev.me"

cloudflare_record_name = "@"

cloudflare_user_email = "<REDACTED>"

cloudflare_global_api_key = "<REDACTED>"

static_assets_bucket_domain_name = "vkev2406-infrastructure-khanghv2406-us-east-1-terraform-state.s3.us-east-1.amazonaws.com"
