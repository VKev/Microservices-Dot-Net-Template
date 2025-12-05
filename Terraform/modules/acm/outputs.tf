output "certificate_arn" {
  description = "ARN of the requested ACM certificate."
  value       = aws_acm_certificate.this.arn
}

output "validation_records" {
  description = "DNS records ACM expects for validation."
  value       = local.validation_records
}
