resource "aws_acm_certificate" "this" {
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
  zone_root = trim(var.domain_name, ".")

  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      # Cloudflare expects names relative to the zone when allow_overwrite is used.
      fqdn  = trimsuffix(dvo.resource_record_name, ".")
      name  = trimsuffix(trimsuffix(dvo.resource_record_name, "."), ".${local.zone_root}")
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
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in local.validation_records : record.fqdn]

  depends_on = [cloudflare_record.acm_validation]
}
