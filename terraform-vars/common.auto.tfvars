# Common Infrastructure Variables
project_name = "vkev2406"
aws_region   = "us-east-1"
region       = "us-east-1"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidr = "10.0.3.0/24"

# EC2 Configuration
instance_type       = "t3.micro"
associate_public_ip = true

# ECS Global Settings
enable_auto_scaling = false

enable_service_connect = true

# HTTPS Configuration Options
# 
# OPTION 1: CloudFront HTTPS (Recommended - free, no custom domain required)
use_cloudfront_https      = true
cloudfront_enable_caching = false

# CloudFront Access Logging (set bucket if enabling)
cloudfront_enable_logging          = false
cloudfront_logging_bucket          = ""
cloudfront_logging_prefix          = "cloudfront-logs/"
cloudfront_logging_include_cookies = false

# OPTION 2: ALB with ACM Certificate (requires custom domain)
certificate_arn       = null
enable_https_redirect = true
