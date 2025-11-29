locals {
  eks_enabled   = var.use_eks
  eks_namespace = "microservices"

  eks_microservices_template_path = abspath("${path.module}/../k8s/microservices.yaml")

  k8s_overrides = try(var.k8s_resources, {})

  eks_storage_class_default = "gp2"
  eks_cluster_addons = merge(
    {
      "vpc-cni" = {
        most_recent = true
        configuration_values = jsonencode({
          env = {
            ENABLE_PREFIX_DELEGATION = "true"
            WARM_PREFIX_TARGET       = "1"
          }
        })
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

  eks_images = local.eks_enabled ? {
    redis      = "${var.services["redis"].ecs_container_image_repository_url}:${var.services["redis"].ecs_container_image_tag}"
    rabbitmq   = "${var.services["rabbitmq"].ecs_container_image_repository_url}:${var.services["rabbitmq"].ecs_container_image_tag}"
    n8n        = "${var.services["n8n"].ecs_container_image_repository_url}:${var.services["n8n"].ecs_container_image_tag}"
    user       = "${var.services["user"].ecs_container_image_repository_url}:${var.services["user"].ecs_container_image_tag}"
    guest      = "${var.services["guest"].ecs_container_image_repository_url}:${var.services["guest"].ecs_container_image_tag}"
    apigateway = "${var.services["apigateway"].ecs_container_image_repository_url}:${var.services["apigateway"].ecs_container_image_tag}"
  } : {}

  eks_microservices_content = local.eks_enabled ? (
    var.k8s_microservices_manifest != null && var.k8s_microservices_manifest != "" ?
    var.k8s_microservices_manifest :
    templatefile(local.eks_microservices_template_path, merge({
      namespace        = local.eks_namespace
      redis_image      = lookup(local.eks_images, "redis", "")
      rabbitmq_image   = lookup(local.eks_images, "rabbitmq", "")
      n8n_image        = lookup(local.eks_images, "n8n", "")
      user_image       = lookup(local.eks_images, "user", "")
      guest_image      = lookup(local.eks_images, "guest", "")
      apigateway_image = lookup(local.eks_images, "apigateway", "")
      storage_class    = local.eks_storage_class

      redis_resources      = local.eks_resources.redis
      rabbitmq_resources   = local.eks_resources.rabbitmq
      n8n_resources        = local.eks_resources.n8n
      n8n_proxy_resources  = local.eks_resources.n8n_proxy
      guest_resources      = local.eks_resources.guest
      user_resources       = local.eks_resources.user
      apigateway_resources = local.eks_resources.apigateway
    }, local.rds_placeholder_map))
  ) : ""

  # Use external data source to perform string replacements (simulating reduce)
  eks_microservices_content_resolved = local.eks_enabled ? data.external.resolve_manifest[0].result["result"] : ""

}

data "external" "resolve_manifest" {
  count   = local.eks_enabled ? 1 : 0
  program = ["python", "${path.module}/scripts/resolve_placeholders.py"]

  query = {
    content           = local.eks_microservices_content
    replacements_json = jsonencode(local.rds_placeholder_map)
  }
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
  node_instance_types             = ["t3.small"]
  node_iam_role_additional_policies = {
    ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    ecr_ptc      = aws_iam_policy.ecs_task_ecr_ptc.arn
  }
  node_min_size                            = 2
  node_max_size                            = 4
  node_desired_size                        = 4
  node_capacity_type                       = "ON_DEMAND"
  environment                              = "dev"
  enable_cluster_creator_admin_permissions = true
  create_cloudwatch_log_group              = false
  cluster_addons                           = local.eks_cluster_addons

  access_entries = {}
}

resource "aws_security_group_rule" "eks_nodeports_from_alb" {
  count = local.eks_enabled ? 1 : 0

  type                     = "ingress"
  description              = "Allow ALB to reach EKS NodePort services"
  security_group_id        = module.eks[0].node_security_group_id
  source_security_group_id = module.alb.alb_sg_id
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
}

resource "kubernetes_storage_class_v1" "ebs_csi" {
  count = local.eks_enabled && local.eks_storage_class != "" ? 1 : 0

  metadata {
    name = local.eks_storage_class
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [
    aws_eks_addon.ebs_csi
  ]

  provider = kubernetes.eks
}

data "aws_iam_policy_document" "ebs_csi_irsa" {
  count = local.eks_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks[0].oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks[0].cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = local.eks_enabled ? 1 : 0

  name               = "${var.project_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_irsa[0].json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  count = local.eks_enabled ? 1 : 0

  cluster_name                = module.eks[0].cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

locals {
  eks_cluster_name     = local.eks_enabled ? module.eks[0].cluster_name : null
  eks_cluster_endpoint = local.eks_enabled ? module.eks[0].cluster_endpoint : "https://example.invalid"
  eks_cluster_ca_data  = local.eks_enabled ? module.eks[0].cluster_certificate_authority_data : ""
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
  content = local.eks_microservices_content_resolved
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
