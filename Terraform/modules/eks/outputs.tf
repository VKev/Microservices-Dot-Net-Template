output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group for the cluster."
  value       = aws_security_group.eks_cluster.id
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.default.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN used by the worker nodes."
  value       = aws_iam_role.eks_node.arn
}

output "admin_access_entry_id" {
  description = "Access entry granting cluster admin to the Terraform principal."
  value       = aws_eks_access_entry.terraform_admin.id
}

output "admin_access_policy_association_id" {
  description = "Access policy association for Terraform principal."
  value       = aws_eks_access_policy_association.terraform_admin.id
}
