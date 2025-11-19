# Origin Request Policy - Forward ALL headers for payment gateway IPN callbacks
resource "aws_cloudfront_origin_request_policy" "include_cloudfront_headers" {
  name    = "${var.project_name}-cloudfront-headers-policy"
  comment = "Forward all viewer headers + CloudFront headers to support payment gateway IPN (MoMo, ZaloPay, etc.)"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    # Forward ALL viewer headers + whitelisted CloudFront headers
    # This is required for MoMo/ZaloPay IPN callbacks to work correctly
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = [
        "CloudFront-Forwarded-Proto",
        "CloudFront-Viewer-Country",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Is-Tablet-Viewer",
        "CloudFront-Is-Desktop-Viewer"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for ${var.project_name} S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "${var.project_name}-rewrite-static"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrite /s3/* to /* for S3 origin"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    if (uri.startsWith('/s3/')) {
        request.uri = uri.replace('/s3/', '/');
    } else if (uri === '/s3') {
        request.uri = '/';
    }
    return request;
}
EOF
}

resource "aws_cloudfront_distribution" "alb_distribution" {
  enabled             = true
  is_ipv6_enabled     = false # Disabled for MoMo compatibility (MoMo only supports IPv4)
  comment             = "CloudFront distribution for ${var.project_name} ALB with HTTPS"
  price_class         = var.price_class
  http_version        = "http2and3"
  wait_for_deployment = true

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "${var.project_name}-alb-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Custom-Origin"
      value = var.project_name
    }
  }

  dynamic "origin" {
    for_each = var.s3_bucket_domain_name != "" ? [1] : []
    content {
      domain_name              = var.s3_bucket_domain_name
      origin_access_control_id = var.s3_use_oac ? aws_cloudfront_origin_access_control.s3_oac.id : null
      origin_id                = var.s3_origin_id
    }
  }

  default_cache_behavior {
    target_origin_id       = "${var.project_name}-alb-origin"
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods
    compress               = var.compress
    viewer_protocol_policy = var.viewer_protocol_policy

    # AWS Managed CachingDisabled Policy ID (same across all regions)
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = aws_cloudfront_origin_request_policy.include_cloudfront_headers.id
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.s3_bucket_domain_name != "" ? [1] : []
    content {
      path_pattern     = var.s3_path_pattern
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = var.s3_origin_id

      forwarded_values {
        query_string = true
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 3600
      max_ttl                = 86400
      compress               = true

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.rewrite_uri.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = var.viewer_min_protocol_version
  }

  # CloudFront access logging (optional)
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = "${var.logging_bucket}.s3.amazonaws.com"
      prefix          = var.logging_prefix
      include_cookies = var.logging_include_cookies
    }
  }

  tags = {
    Name        = "${var.project_name}-cloudfront-distribution"
    Project     = var.project_name
    Environment = "production"
    Purpose     = "HTTPS termination for ALB"
  }

  # Ensure policy exists before CF validates behavior
  depends_on = [
    aws_cloudfront_origin_request_policy.include_cloudfront_headers
  ]
}
