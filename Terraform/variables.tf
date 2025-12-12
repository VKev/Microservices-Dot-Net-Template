## Removed CloudFront/Wasabi related variables

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# VPC Variables
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "projectname"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (at least two for RDS subnet group)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# EC2 Variables
variable "instance_type" {
  description = "EC2 instance type (free tier eligible: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "associate_public_ip" {
  description = "Whether to associate an Elastic IP with the EC2 instance"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# ECS Global Variables
variable "enable_auto_scaling" {
  description = "Enable auto scaling for the ECS service"
  type        = bool
  default     = false
}

variable "enable_service_connect" {
  description = "Enable ECS Service Connect across services"
  type        = bool
  default     = false
}

variable "rds" {
  description = "Map of RDS instances to create (keyed, e.g., \"user\", \"guest\")."
  type = map(object({
    db_name                 = optional(string, "defaultdb")
    db_names                = optional(list(string))
    username                = optional(string, "avnadmin")
    password                = optional(string, "")
    engine_version          = optional(string, "15.4")
    instance_class          = optional(string, "db.t3.micro")
    allocated_storage       = optional(number, 20)
    max_allocated_storage   = optional(number, 100)
    backup_retention_period = optional(number, 1)
    deletion_protection     = optional(bool, false)
    publicly_accessible     = optional(bool, false)
    port                    = optional(number, 5432)
    tags                    = optional(map(string), {})
  }))
  default = {}
}
variable "service_discovery_domain_suffix" {
  description = "Suffix used to build the private DNS namespace for service discovery (e.g. \"svc\" => <project>.svc)"
  type        = string
  default     = "svc"
}

# Docker Hub pull-through cache configuration
variable "dockerhub_pull_through_prefix" {
  description = "ECR repository prefix for Docker Hub pull-through cache rule."
  type        = string
  default     = "dockerhub"
}

variable "dockerhub_pull_through_registry" {
  description = "Upstream Docker Hub registry URL."
  type        = string
  default     = "registry-1.docker.io"
}

variable "dockerhub_credentials_secret_arn" {
  description = "Secrets Manager ARN containing Docker Hub credentials (username/password) for the pull-through cache rule."
  type        = string
  default     = null
}

variable "dockerhub_username" {
  description = "Docker Hub username used to create the pull-through cache rule (ignored if dockerhub_credentials_secret_arn is set)."
  type        = string
  default     = ""
}

variable "dockerhub_password" {
  description = "Docker Hub password/token used to create the pull-through cache rule (ignored if dockerhub_credentials_secret_arn is set)."
  type        = string
  default     = ""
  sensitive   = true
}

# SSL/TLS Certificate Variable
variable "certificate_arn" {
  description = "ARN of the SSL/TLS certificate from AWS Certificate Manager for HTTPS listener. If not provided, only HTTP listener will be created."
  type        = string
  default     = null
}

variable "enable_https_redirect" {
  description = "Whether to redirect HTTP traffic to HTTPS. Only applies if certificate_arn is provided."
  type        = bool
  default     = true
}

# CloudFront Configuration
variable "use_cloudfront_https" {
  description = "Whether to use CloudFront to provide free HTTPS for ALB. When true, CloudFront will be created in front of ALB."
  type        = bool
  default     = true
}

variable "use_cloudflare" {
  description = "Whether to use Cloudflare for DNS and HTTPS. Prioritized over CloudFront if both are true."
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token for managing DNS records."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID used when creating resources like workers or R2 buckets."
  type        = string
  default     = ""
}

variable "cloudflare_user_email" {
  description = "Cloudflare user email that owns the API token."
  type        = string
  default     = ""
}

variable "cloudflare_global_api_key" {
  description = "Cloudflare Global API Key used for legacy authentication flows (required by cf-nuke)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID where the domain is managed."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "The domain name managed in Cloudflare (e.g., example.com)."
  type        = string
  default     = ""
}

variable "cloudflare_record_name" {
  description = "The subdomain/record name to create (e.g., api, www, or @)."
  type        = string
  default     = "@"
}

variable "use_eks" {
  description = "When true, deploy workloads to EKS instead of ECS."
  type        = bool
  default     = false
}

variable "eks_cluster_addons" {
  description = "Optional extra EKS cluster addons map passed to the EKS module (merged with defaults)."
  type        = map(any)
  default     = {}
}

variable "k8s_resources" {
  description = "Override Kubernetes replicas/CPU/memory/storage class for EKS deployments."
  type        = any
  default     = {}
}

variable "k8s_microservices_manifest" {
  description = "Override the rendered Kubernetes YAML (multi-doc) for the microservices namespace. When set, Terraform will use this value directly instead of rendering k8s/microservices.yaml."
  type        = string
  default     = null
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.34"
}

variable "eks_cluster_endpoint_public_access" {
  description = "Allow public access to the EKS API endpoint (disable for private-only clusters)."
  type        = bool
  default     = true
}

variable "eks_cluster_endpoint_private_access" {
  description = "Allow access to the EKS API endpoint from within the VPC."
  type        = bool
  default     = true
}

variable "eks_node_instance_types" {
  description = "List of instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in the EKS managed node group."
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in the EKS managed node group."
  type        = number
  default     = 3
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the EKS managed node group."
  type        = number
  default     = 4
}

variable "eks_node_capacity_type" {
  description = "Capacity type for the EKS managed node group (ON_DEMAND or SPOT)."
  type        = string
  default     = "ON_DEMAND"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  type        = string
  default     = "dev"
}

variable "eks_enable_cluster_creator_admin_permissions" {
  description = "Whether to grant admin permissions to the cluster creator."
  type        = bool
  default     = true
}

variable "eks_create_cloudwatch_log_group" {
  description = "Whether to create a CloudWatch log group for the EKS cluster."
  type        = bool
  default     = false
}

variable "eks_default_storage_class_name" {
  description = "Default storage class name for EKS (fallback if not specified in k8s_resources)."
  type        = string
  default     = "gp2"
}

variable "eks_ebs_volume_type" {
  description = "EBS volume type for the CSI driver storage class (e.g., gp2, gp3, io1)."
  type        = string
  default     = "gp3"
}

variable "kubernete" {
  description = "Kubernetes deployment settings (used when use_eks = true)."
  type        = any
  default     = null
}

variable "cloudfront_enable_caching" {
  description = "Whether to enable CloudFront caching. Set to false to pass all requests directly to ALB without caching."
  type        = bool
  default     = false
}

variable "cloudfront_enable_logging" {
  description = "Enable CloudFront access logging to S3 for debugging (e.g., MoMo IPN issues)"
  type        = bool
  default     = false
}

variable "cloudfront_logging_bucket" {
  description = "S3 bucket name for CloudFront access logs (without .s3.amazonaws.com suffix). Required if cloudfront_enable_logging = true"
  type        = string
  default     = ""
}

variable "cloudfront_logging_prefix" {
  description = "Prefix for CloudFront log files in S3 bucket"
  type        = string
  default     = "cloudfront-logs/"
}

variable "cloudfront_logging_include_cookies" {
  description = "Include cookies in CloudFront access logs"
  type        = bool
  default     = false
}

# Service Definitions Variable
variable "services" {
  description = "Configuration for each microservice"
  type = map(object({
    # ALB Target Group attributes
    alb_target_group_port     = number
    alb_target_group_protocol = string
    alb_target_group_type     = string
    alb_health_check = object({
      enabled             = bool
      path                = string
      port                = string
      protocol            = string
      matcher             = string
      interval            = number
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
    })

    # ALB Listener Rule attributes
    alb_listener_rule_priority = number
    alb_listener_rule_conditions = list(object({
      path_pattern = optional(object({
        values = list(string)
      }))
      # Add other condition types here if needed (e.g., host_header)
    }))
    ecs_service_connect_dns_name       = string # Optional custom DNS name for the service
    ecs_service_connect_discovery_name = string # Optional custom DNS name for the service
    ecs_service_connect_port_name      = string # Optional custom DNS name for the service
    # ECS Container attributes
    ecs_container_name_suffix          = string # e.g. "microservice" to form "project-key-suffix"
    ecs_container_image_repository_url = string
    ecs_container_image_tag            = string
    ecs_container_cpu                  = number
    ecs_container_memory               = number
    ecs_container_essential            = bool
    ecs_container_port_mappings = list(object({
      container_port = number
      host_port      = optional(number, 0)
      protocol       = optional(string, "tcp")
      name           = optional(string)
      app_protocol   = optional(string)
    }))
    ecs_environment_variables = list(object({
      name  = string
      value = string
    }))
    ecs_container_health_check = optional(object({
      command     = list(string)
      interval    = number
      timeout     = number
      retries     = number
      startPeriod = number
    }))
    mount_points = optional(list(object({
      source_volume  = string
      container_path = string
      read_only      = optional(bool, false)
    })), [])
    depends_on              = optional(list(string)) # Container names this depends on
    command                 = optional(list(string))
    ecs_task_cpu            = optional(number)
    ecs_task_memory         = optional(number)
    ecs_desired_count       = optional(number)
    ecs_assign_public_ip    = optional(bool)
    ecs_enable_auto_scaling = optional(bool)
  }))

}

variable "ecs_service_groups" {
  description = "Map of ECS service groups (Tasks/Services) and their constituent containers."
  type = map(object({
    desired_count = number
    containers    = list(string) # Keys from var.services
    volumes = optional(list(object({
      name      = string
      host_path = string
    })), [])
    dependencies = optional(list(string), []) # Keys from var.ecs_service_groups
  }))
  default = {}
}

variable "static_assets_bucket_domain_name" {
  description = "Domain name of the S3 bucket for static assets (e.g., my-bucket.s3.us-east-1.amazonaws.com)"
  type        = string
  default     = ""
}
