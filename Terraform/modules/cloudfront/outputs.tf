output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.alb_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.alb_distribution.arn
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution (use this for HTTPS access)"
  value       = aws_cloudfront_distribution.alb_distribution.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID that can be used to route to the distribution"
  value       = aws_cloudfront_distribution.alb_distribution.hosted_zone_id
}

output "cloudfront_status" {
  description = "The current status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.alb_distribution.status
}

output "cloudfront_https_url" {
  description = "The full HTTPS URL to access your application via CloudFront"
  value       = "https://${aws_cloudfront_distribution.alb_distribution.domain_name}"
}
