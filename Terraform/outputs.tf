locals {
  cloudfront_enabled  = length(module.cloudfront) > 0
  cloudfront_endpoint = local.cloudfront_enabled ? module.cloudfront[0].cloudfront_https_url : null
  cloudflare_endpoint = var.use_cloudflare ? "https://${var.cloudflare_record_name == "@" ? var.domain_name : "${var.cloudflare_record_name}.${var.domain_name}"}" : null
}

output "alb_dns_name" {
  description = "Public DNS name for the Application Load Balancer."
  value       = module.alb.alb_dns_name
}

# CloudFront Outputs (when enabled)
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (use this for HTTPS access when CloudFront is enabled)"
  value       = local.cloudfront_enabled ? module.cloudfront[0].cloudfront_domain_name : null
}

output "cloudfront_https_url" {
  description = "Full HTTPS URL to access your application via CloudFront"
  value       = local.cloudfront_endpoint
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = local.cloudfront_enabled ? module.cloudfront[0].cloudfront_distribution_id : null
}

output "primary_endpoint" {
  description = "Primary endpoint to access your application (Cloudflare if enabled, else CloudFront if enabled, else ALB HTTP)"
  value = coalesce(
    local.cloudflare_endpoint,
    local.cloudfront_endpoint,
    "http://${module.alb.alb_dns_name}"
  )
}

output "rds_endpoints" {
  description = "Map of RDS endpoints keyed by instance key (e.g., user, guest)."
  value       = { for k, m in module.rds : k => m.endpoint }
}

output "rds_usernames" {
  description = "Map of RDS usernames keyed by instance key."
  value       = { for k, m in module.rds : k => m.username }
}

output "rds_passwords" {
  description = "Map of RDS passwords keyed by instance key."
  value       = { for k, m in module.rds : k => m.password }
  sensitive   = true
}


# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# EC2 Outputs
output "ec2_instance_ids" {
  description = "Map of ECS container instance IDs keyed by group name"
  value       = try(module.ec2[0].instance_ids, {})
}

output "ec2_public_ips" {
  description = "Map of public IP addresses for ECS container instances"
  value       = try(module.ec2[0].instance_public_ips, {})
}

output "ec2_private_ips" {
  description = "Map of private IP addresses for ECS container instances"
  value       = try(module.ec2[0].instance_private_ips, {})
}

output "ec2_public_dns" {
  description = "Map of public DNS names for ECS container instances"
  value       = try(module.ec2[0].instance_public_dns, {})
}

output "ec2_elastic_ips" {
  description = "Map of Elastic IPs attached to ECS container instances"
  value       = try(module.ec2[0].elastic_ips, {})
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = try(module.ec2[0].ecs_cluster_name, null)
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = try(module.ec2[0].ecs_cluster_arn, null)
}

output "ec2_private_key_pem" {
  description = "Private key for EC2 instance."
  value       = try(module.ec2[0].ec2_private_key_pem, null)
  sensitive   = true
}

# EKS Outputs (populated when use_eks = true)
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.use_eks ? module.eks[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = var.use_eks ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data"
  value       = var.use_eks ? module.eks[0].cluster_certificate_authority_data : null
}

output "eks_cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = var.use_eks ? module.eks[0].cluster_security_group_id : null
}

output "eks_node_security_group_id" {
  description = "Node shared security group ID"
  value       = var.use_eks ? module.eks[0].node_security_group_id : null
}

## Optional ECS outputs commented out (kept minimal)
