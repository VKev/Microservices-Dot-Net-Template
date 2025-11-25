locals {
  eks_enabled = var.use_eks
}

module "eks" {
  count  = local.eks_enabled ? 1 : 0
  source = "./modules/eks"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_version                 = var.eks_cluster_version
  cluster_endpoint_public_access  = var.eks_cluster_endpoint_public_access
  cluster_endpoint_private_access = var.eks_cluster_endpoint_private_access
  node_instance_types             = ["t3.micro"]
  node_min_size                   = 2
  node_max_size                   = 4
  node_desired_size               = 4
  node_capacity_type              = "ON_DEMAND"
  environment                     = "dev"
}

locals {
  eks_cluster_name      = local.eks_enabled ? module.eks[0].cluster_name : null
  eks_cluster_endpoint  = local.eks_enabled ? module.eks[0].cluster_endpoint : "https://example.invalid"
  eks_cluster_ca_data   = local.eks_enabled ? module.eks[0].cluster_certificate_authority_data : ""
  eks_microservices_yaml = abspath("${path.module}/../k8s/microservices.yaml")
}

data "aws_eks_cluster_auth" "eks" {
  count = local.eks_enabled ? 1 : 0
  name  = local.eks_cluster_name
}



# Kubectl provider – dùng để apply YAML K8s (kubectl_manifest)
provider "kubectl" {
  alias                  = "eks"
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = local.eks_enabled ? base64decode(local.eks_cluster_ca_data) : ""
  token                  = local.eks_enabled ? data.aws_eks_cluster_auth.eks[0].token : ""
  load_config_file       = false
}

# 1) Đọc file YAML multi-doc
data "kubectl_file_documents" "microservices" {
  count   = local.eks_enabled ? 1 : 0
  content = file(local.eks_microservices_yaml)
}

# 2) Apply từng manifest trong file YAML
resource "kubectl_manifest" "microservices" {
  # mỗi phần tử là 1 manifest YAML (Namespace, Secret, Deployment, Service,...)
  for_each = local.eks_enabled ? data.kubectl_file_documents.microservices[0].documents : {}

  yaml_body = each.value

  # Đảm bảo cluster EKS tạo xong trước khi apply YAML
  depends_on = local.eks_enabled ? [module.eks[0]] : []
  provider   = kubectl.eks
}
