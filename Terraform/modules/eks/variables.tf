variable "project_name" {
  description = "Project name for tagging and naming."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for EKS control plane and nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets (used for the control plane if needed / ALB exposure)."
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.3"
}

variable "node_instance_type" {
  description = "Instance type for managed node group."
  type        = string
  default     = "t3.micro"
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Min node count."
  type        = number
  default     = 4
}

variable "node_max_size" {
  description = "Max node count."
  type        = number
  default     = 4
}
