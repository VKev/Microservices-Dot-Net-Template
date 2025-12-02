locals {
  eks_name_prefix = coalesce(var.name_prefix, var.project_name)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Tên & version cluster – theo doc EKS khuyến nghị dùng
  # phiên bản Kubernetes mới nhất trong standard support
  cluster_name    = "${local.eks_name_prefix}-eks"
  cluster_version = var.cluster_version

  # Network – EKS standard: control plane + managed node group trong VPC riêng
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Bật IRSA để pod có thể dùng IAM Roles for Service Accounts (best practice)
  enable_irsa = true

  # Grant cluster creator (IAM identity đang chạy Terraform) quyền admin Kubernetes
  # để sau đó có thể tạo access entries / aws-auth / RBAC theo doc
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Endpoint exposure – dev có thể cho public, prod nên tắt public endpoint
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_addons                  = var.cluster_addons

  # Managed node group – theo doc "manage compute resources by using nodes"
  eks_managed_node_group_defaults = {
    instance_types               = var.node_instance_types
    iam_role_additional_policies = var.node_iam_role_additional_policies
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = var.node_ami_type
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      capacity_type = var.node_capacity_type # ON_DEMAND / SPOT
    }
  }

  access_entries = var.access_entries

  create_cloudwatch_log_group = var.create_cloudwatch_log_group

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
    },
    var.tags
  )
}
