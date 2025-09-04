## Removed CloudFront outputs



# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.vpc.private_subnet_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# EC2 Outputs
output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ip
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.instance_private_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.ec2.instance_public_dns
}

output "elastic_ip" {
  description = "Elastic IP address associated with the instance"
  value       = module.ec2.elastic_ip
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ec2.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ec2.ecs_cluster_arn
}

output "ec2_private_key_pem" {
  description = "Private key for EC2 instance."
  value       = module.ec2.ec2_private_key_pem
  sensitive   = true
}

## Optional ECS outputs commented out (kept minimal)
