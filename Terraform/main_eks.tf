locals {
  eks_enabled = var.use_eks
}

module "eks" {
  source = "./modules/eks"
  count  = local.eks_enabled ? 1 : 0

  project_name       = var.project_name
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_instance_type = var.instance_type
  node_desired_size  = 4
  node_min_size      = 4
  node_max_size      = 4
}
