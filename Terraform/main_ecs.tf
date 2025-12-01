module "ecs_dynamic" {
  for_each = var.use_eks ? {} : var.ecs_service_groups
  source   = "./modules/ecs"

  # Reference upstream ECS services so Terraform builds an explicit dependency chain between service groups.
  upstream_service_arns = [
    for dep in coalescelist(try(each.value.dependencies, []), []) :
    try(module.ecs_dynamic[dep].ecs_service_arns[dep], "")
    if contains(keys(var.ecs_service_groups), dep)
  ]

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = try(module.ec2[0].ecs_cluster_arn, null)
  ecs_cluster_name         = try(module.ec2[0].ecs_cluster_name, null)
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = each.value.desired_count
  service_names            = [each.key]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"

  service_dependencies = {
    (each.key) = each.value.dependencies
  }

  has_dependencies = length(each.value.dependencies) > 0

  enable_auto_scaling    = var.enable_auto_scaling
  enable_service_connect = var.enable_service_connect
  wait_for_steady_state  = false

  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    (each.key) = [
      for container_name in each.value.containers :
      {
        port_name      = var.services[container_name].ecs_service_connect_port_name
        discovery_name = var.services[container_name].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services[container_name].ecs_service_connect_dns_name
            port     = var.services[container_name].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      if var.services[container_name].ecs_service_connect_dns_name != null && var.services[container_name].ecs_service_connect_dns_name != ""
    ]
  }

  service_definitions = {
    (each.key) = {
      task_cpu         = sum([for c in each.value.containers : var.services[c].ecs_container_cpu]) + 128
      task_memory      = sum([for c in each.value.containers : var.services[c].ecs_container_memory]) + 128
      desired_count    = each.value.desired_count
      assign_public_ip = false

      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == ${each.key}"
        }
      ]

      volumes = [
        for v in each.value.volumes : {
          name      = v.name
          host_path = replace(v.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)
        }
      ]

      containers = [
        for container_name in each.value.containers :
        {
          name                 = var.services[container_name].ecs_container_name_suffix
          image_repository_url = var.services[container_name].ecs_container_image_repository_url
          image_tag            = var.services[container_name].ecs_container_image_tag
          cpu                  = var.services[container_name].ecs_container_cpu
          memory               = var.services[container_name].ecs_container_memory
          essential            = var.services[container_name].ecs_container_essential
          port_mappings        = var.services[container_name].ecs_container_port_mappings

          environment_variables = [
            for env in var.services[container_name].ecs_environment_variables :
            merge(env, {
              value = replace(
                replace(
                  replace(
                    can(element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env.value), 0)) ? replace(
                      env.value,
                      element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env.value), 0),
                      lookup(local.rds_placeholder_map, element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env.value), 0), env.value)
                    ) : env.value,
                    "TERRAFORM_PUBLIC_ENDPOINT", local.public_endpoint
                  ),
                  "TERRAFORM_N8N_PROXY_DEPTH", tostring(local.n8n_proxy_depth)
                ),
                "TERRAFORM_PROJECT_NAME", var.project_name
              )
            })
          ]

          command = var.services[container_name].command != null ? [
            for cmd_part in var.services[container_name].command :
            replace(cmd_part, "TERRAFORM_N8N_PROXY_DEPTH", tostring(local.n8n_proxy_depth))
          ] : null

          health_check = var.services[container_name].ecs_container_health_check

          mount_points = var.services[container_name].mount_points

          depends_on = var.services[container_name].depends_on != null ? var.services[container_name].depends_on : []
        }
      ]

      target_groups = [
        for container_name in each.value.containers :
        {
          target_group_arn = module.alb.target_group_arns_map[container_name]
          container_name   = var.services[container_name].ecs_container_name_suffix
          container_port   = var.services[container_name].ecs_container_port_mappings[0].container_port
        }
        if var.services[container_name].alb_target_group_port != null
      ]
    }
  }
}
