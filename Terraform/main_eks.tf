locals {
  eks_enabled   = var.use_eks
  eks_namespace = "microservices"

  eks_microservices_template = abspath("${path.module}/../k8s/microservices.yaml")

  k8s_overrides = try(var.k8s_resources, {})

  eks_storage_class_default = "gp2"

  eks_cluster_addons = merge(
    {
      "aws-ebs-csi-driver" = {
        most_recent = true
      }
    },
    try(var.eks_cluster_addons, {})
  )

  # Resources/replicas/images for each workload are fully provided via k8s.auto.tfvars (no defaults here)
  eks_resources = local.k8s_overrides

  eks_storage_class = try(
    local.k8s_overrides.storage_class,
    try(local.k8s_overrides["storage_class"], local.eks_storage_class_default)
  )

  pvc_storage_class_line = local.eks_storage_class != "" ? "  storageClassName: ${local.eks_storage_class}" : ""

  eks_images = local.eks_enabled ? {
    redis      = "${var.services["redis"].ecs_container_image_repository_url}:${var.services["redis"].ecs_container_image_tag}"
    rabbitmq   = "${var.services["rabbitmq"].ecs_container_image_repository_url}:${var.services["rabbitmq"].ecs_container_image_tag}"
    n8n        = "${var.services["n8n"].ecs_container_image_repository_url}:${var.services["n8n"].ecs_container_image_tag}"
    user       = "${var.services["user"].ecs_container_image_repository_url}:${var.services["user"].ecs_container_image_tag}"
    guest      = "${var.services["guest"].ecs_container_image_repository_url}:${var.services["guest"].ecs_container_image_tag}"
    apigateway = "${var.services["apigateway"].ecs_container_image_repository_url}:${var.services["apigateway"].ecs_container_image_tag}"
  } : {}

  eks_microservices_content = local.eks_enabled ? templatefile(local.eks_microservices_template, {
    namespace        = local.eks_namespace
    redis_image      = lookup(local.eks_images, "redis", "")
    rabbitmq_image   = lookup(local.eks_images, "rabbitmq", "")
    n8n_image        = lookup(local.eks_images, "n8n", "")
    user_image       = lookup(local.eks_images, "user", "")
    guest_image      = lookup(local.eks_images, "guest", "")
    apigateway_image = lookup(local.eks_images, "apigateway", "")
    storage_class    = local.eks_storage_class
    pvc_storage_class = local.pvc_storage_class_line

    redis_resources      = local.eks_resources.redis
    rabbitmq_resources   = local.eks_resources.rabbitmq
    n8n_resources        = local.eks_resources.n8n
    n8n_proxy_resources  = local.eks_resources.n8n_proxy
    guest_resources      = local.eks_resources.guest
    user_resources       = local.eks_resources.user
    apigateway_resources = local.eks_resources.apigateway
  }) : ""
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
  enable_cluster_creator_admin_permissions = true
  create_cloudwatch_log_group     = false
  cluster_addons                  = local.eks_cluster_addons

  access_entries = {}
}

locals {
  eks_cluster_name      = local.eks_enabled ? module.eks[0].cluster_name : null
  eks_cluster_endpoint  = local.eks_enabled ? module.eks[0].cluster_endpoint : "https://example.invalid"
  eks_cluster_ca_data   = local.eks_enabled ? module.eks[0].cluster_certificate_authority_data : ""
}

data "aws_eks_cluster_auth" "eks" {
  count = local.eks_enabled ? 1 : 0
  name  = local.eks_cluster_name
  depends_on = [
    module.eks
  ]
}



# Kubernetes provider – dùng cho những resource kiểu kubernetes_* (nếu sau này bạn dùng)
provider "kubernetes" {
  alias                  = "eks"
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = local.eks_enabled ? base64decode(local.eks_cluster_ca_data) : ""
  token                  = local.eks_enabled ? data.aws_eks_cluster_auth.eks[0].token : ""
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
  content = local.eks_microservices_content
}

resource "kubernetes_namespace" "microservices" {
  count = local.eks_enabled ? 1 : 0
  metadata {
    name = local.eks_namespace
  }

  provider = kubernetes.eks
}

# 2) Apply từng manifest trong file YAML
resource "kubectl_manifest" "microservices_prereq" {
  # Apply Secrets/ConfigMaps/PVC/Services first
  for_each = local.eks_enabled ? {
    for idx, doc in data.kubectl_file_documents.microservices[0].documents :
    idx => doc
    if contains(["Secret", "ConfigMap", "PersistentVolumeClaim", "Service"], try(yamldecode(doc).kind, ""))
  } : {}

  yaml_body = each.value

  depends_on = [
    module.eks,
    kubernetes_namespace.microservices
  ]
  provider = kubectl.eks
}

resource "kubectl_manifest" "microservices_workloads" {
  # Apply Deployments after prereqs exist
  for_each = local.eks_enabled ? {
    for idx, doc in data.kubectl_file_documents.microservices[0].documents :
    idx => doc
    if try(yamldecode(doc).kind, "") == "Deployment"
  } : {}

  yaml_body = each.value

  depends_on = [
    module.eks,
    kubernetes_namespace.microservices,
    kubectl_manifest.microservices_prereq
  ]
  provider = kubectl.eks
}
