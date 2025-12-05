variable "domain_name" {
  description = "Primary domain to request a certificate for (e.g., example.com)."
  type        = string
}

variable "subject_alternative_names" {
  description = "Optional additional SANs (e.g., api.example.com, *.example.com)."
  type        = list(string)
  default     = []
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID where the domain is hosted."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions for the zone."
  type        = string
  sensitive   = true
}

variable "validation_record_ttl" {
  description = "TTL (seconds) for the ACM validation CNAME."
  type        = number
  default     = 300
}

variable "aws_region" {
  description = "AWS region to request the ACM certificate in."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags to apply to the ACM certificate."
  type        = map(string)
  default     = {}
}
