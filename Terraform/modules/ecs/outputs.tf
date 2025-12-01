output "ecs_service_names" {
  description = "Map of ECS service logical names to AWS ECS service names"
  value = merge(
    { for name, svc in aws_ecs_service.this_no_deps : name => svc.name },
    { for name, svc in aws_ecs_service.this_with_deps : name => svc.name }
  )
}

output "ecs_service_arns" {
  description = "Map of ECS service logical names to ECS service ARNs"
  value = merge(
    { for name, svc in aws_ecs_service.this_no_deps : name => svc.id },
    { for name, svc in aws_ecs_service.this_with_deps : name => svc.id }
  )
}


output "task_definition_arns" {
  description = "Map of ECS service logical names to task definition ARNs"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.arn }
}

output "task_definition_families" {
  description = "Map of ECS service logical names to task definition families"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.family }
}

output "task_definition_revisions" {
  description = "Map of ECS service logical names to task definition revisions"
  value       = { for name, td in aws_ecs_task_definition.this : name => td.revision }
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.shared_log_group_name
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role assumed by the tasks"
  value       = var.shared_task_role_arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the IAM role used for ECS task execution"
  value       = var.shared_execution_role_arn
}

output "task_security_group_id" {
  description = "ID of the task security group"
  value       = var.shared_task_sg_id
}

output "service_discovery_namespace_arn" {
  description = "ARN of the Cloud Map private DNS namespace (passed via input)"
  value       = var.service_connect_namespace
}

