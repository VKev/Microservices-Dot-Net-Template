provider "aws" {
  alias  = "acm"
  region = var.aws_region
}

resource "aws_acm_certificate" "this" {
  provider                  = aws.acm
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"
  key_algorithm             = "RSA_2048"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name  = trimsuffix(dvo.resource_record_name, ".")
      type  = dvo.resource_record_type
      value = trimsuffix(dvo.resource_record_value, ".")
    }
  }
}

resource "cloudflare_record" "acm_validation" {
  for_each = local.validation_records

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  ttl     = var.validation_record_ttl
  proxied = false

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider                 = aws.acm
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in local.validation_records : record.name]

  depends_on = [cloudflare_record.acm_validation]
}
