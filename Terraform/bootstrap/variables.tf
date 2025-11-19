variable "region" {
  description = "AWS region to create backend resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for backend resources"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution to allow access to the bucket"
  type        = string
  default     = null
}
