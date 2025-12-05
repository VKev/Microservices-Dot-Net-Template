locals {
  effective_certificate_arn = coalesce(var.certificate_arn, try(module.acm[0].certificate_arn, null))
}

module "acm" {
  count = var.use_cloudflare && var.certificate_arn == null ? 1 : 0

  source = "./modules/acm"

  providers = {
    aws = aws
  }

  domain_name               = var.domain_name
  subject_alternative_names = []
  cloudflare_zone_id        = var.cloudflare_zone_id
  cloudflare_api_token      = var.cloudflare_api_token
  aws_region                = var.aws_region
  tags                      = { Project = var.project_name }
}
