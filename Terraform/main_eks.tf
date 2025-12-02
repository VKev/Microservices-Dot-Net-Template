locals {
  eks_enabled   = var.use_eks
  eks_namespace = var.project_name
  eks_name_prefix = "${substr(replace(var.project_name, "_", "-"), 0, 18)}-${substr(md5(var.project_name), 0, 4)}"

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

  eks_storage_class = try(
    var.k8s_resources.storage_class,
    try(var.k8s_resources["storage_class"], var.eks_default_storage_class_name)
  )

  eks_microservices_content = local.eks_enabled ? (
    var.k8s_microservices_manifest != null ? var.k8s_microservices_manifest : ""
  ) : ""

  # We use the raw content for parsing documents to ensure keys are known at plan time.
  # The actual resolution happens via external data source on the individual documents.
  eks_microservices_content_resolved = local.eks_microservices_content

}

data "external" "resolve_manifest" {
  count   = local.eks_enabled ? 1 : 0
  program = ["python", "${path.module}/scripts/resolve_placeholders.py"]

  query = {
    docs_map_json = jsonencode({
      for idx, doc in data.kubectl_file_documents.microservices[0].documents :
      idx => doc
    })
    replacements_json = jsonencode(merge(
      local.rds_placeholder_map,
      {
        "TERRAFORM_NAMESPACE" = local.eks_namespace
      }
    ))
  }
}

module "eks" {
  count  = local.eks_enabled ? 1 : 0
  source = "./modules/eks"

  project_name       = var.project_name
  name_prefix        = local.eks_name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_version                 = var.eks_cluster_version
  cluster_endpoint_public_access  = var.eks_cluster_endpoint_public_access
  cluster_endpoint_private_access = var.eks_cluster_endpoint_private_access
  node_instance_types             = var.eks_node_instance_types
  node_iam_role_additional_policies = {
    ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    ecr_ptc      = aws_iam_policy.ecs_task_ecr_ptc.arn
  }
  node_min_size                            = var.eks_node_min_size
  node_max_size                            = var.eks_node_max_size
  node_desired_size                        = var.eks_node_desired_size
  node_capacity_type                       = var.eks_node_capacity_type
  environment                              = var.environment
  enable_cluster_creator_admin_permissions = var.eks_enable_cluster_creator_admin_permissions
  create_cloudwatch_log_group              = var.eks_create_cloudwatch_log_group
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
    type      = var.eks_ebs_volume_type
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

  yaml_body = data.external.resolve_manifest[0].result[each.key]

  depends_on = [
    module.eks,
    kubernetes_namespace.microservices,
    data.external.resolve_manifest
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

  yaml_body = data.external.resolve_manifest[0].result[each.key]

  depends_on = [
    module.eks,
    kubernetes_namespace.microservices,
    kubectl_manifest.microservices_prereq,
    data.external.resolve_manifest
  ]
  provider = kubectl.eks
}
