variable "project_name" {
  type        = string
  description = "Project name, used as EKS cluster prefix"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix used for cluster and IAM names to satisfy AWS length limits"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for worker nodes and control plane"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  # Theo doc EKS: dùng bản mới nhất trong standard support (hiện tại: 1.30)
  default     = "1.30"
}

variable "enable_cluster_creator_admin_permissions" {
  type        = bool
  description = "Give the cluster creator IAM principal admin access in Kubernetes (via EKS access entries)"
  default     = true
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Whether the EKS API endpoint is accessible over the public internet"
  # Dev: true; Prod: nên set false và truy cập qua VPN/DirectConnect
  default     = true
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Whether the EKS API endpoint is accessible from within the VPC"
  default     = true
}

variable "cluster_addons" {
  type        = map(any)
  description = "EKS cluster addons map passed to terraform-aws-modules/eks"
  default     = {}
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for EKS managed node groups"
  default     = ["t3.small"]
}

variable "node_iam_role_additional_policies" {
  type        = map(string)
  description = "Additional IAM policy ARNs to attach to EKS managed node group IAM roles (e.g., ECR access)"
  default     = {}
}

variable "node_ami_type" {
  type        = string
  description = "AMI type for EKS nodes"
  # theo module EKS v20, AL2023 là default & recommended
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_min_size" {
  type        = number
  description = "Min number of nodes"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Max number of nodes"
  default     = 4
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of nodes"
  default     = 2
}

variable "node_capacity_type" {
  type        = string
  description = "Capacity type for node group (ON_DEMAND or SPOT)"
  default     = "ON_DEMAND"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/stage/prod)"
  default     = "dev"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags for all EKS resources"
  default     = {}
}

variable "access_entries" {
  type        = map(any)
  description = "EKS access entries map passed to terraform-aws-modules/eks"
  default     = {}
}

variable "create_cloudwatch_log_group" {
  type        = bool
  description = "Whether to create the CloudWatch log group for control plane logs"
  default     = true
}
