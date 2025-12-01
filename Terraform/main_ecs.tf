# Server 1 - No dependencies
module "ecs_server_1" {
  count  = var.use_eks ? 0 : 1
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = try(module.ec2[0].ecs_cluster_arn, null)
  ecs_cluster_name         = try(module.ec2[0].ecs_cluster_name, null)
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = var.ecs_service_groups["server-1"].desired_count
  service_names            = ["server-1"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"

  service_dependencies = {
    "server-1" = []
  }

  has_dependencies = false

  enable_auto_scaling    = var.enable_auto_scaling
  enable_service_connect = var.enable_service_connect
  wait_for_steady_state  = true

  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    "server-1" = [
      for container_name in var.ecs_service_groups["server-1"].containers :
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
    "server-1" = {
      task_cpu         = sum([for c in var.ecs_service_groups["server-1"].containers : var.services[c].ecs_container_cpu]) + 128
      task_memory      = sum([for c in var.ecs_service_groups["server-1"].containers : var.services[c].ecs_container_memory]) + 128
      desired_count    = var.ecs_service_groups["server-1"].desired_count
      assign_public_ip = false

      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-1"
        }
      ]

      volumes = [
        for v in var.ecs_service_groups["server-1"].volumes : {
          name      = v.name
          host_path = replace(v.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)
        }
      ]

      containers = [
        for container_name in var.ecs_service_groups["server-1"].containers :
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
        for container_name in var.ecs_service_groups["server-1"].containers :
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

# Server 3 - Depends on server-1
module "ecs_server_3" {
  count  = var.use_eks ? 0 : 1
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = try(module.ec2[0].ecs_cluster_arn, null)
  ecs_cluster_name         = try(module.ec2[0].ecs_cluster_name, null)
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = var.ecs_service_groups["server-3"].desired_count
  service_names            = ["server-3"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"

  service_dependencies = {
    "server-3" = ["server-1"]
  }

  has_dependencies = true

  enable_auto_scaling    = var.enable_auto_scaling
  enable_service_connect = var.enable_service_connect
  wait_for_steady_state  = true

  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    "server-3" = [
      for container_name in var.ecs_service_groups["server-3"].containers :
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
    "server-3" = {
      task_cpu         = sum([for c in var.ecs_service_groups["server-3"].containers : var.services[c].ecs_container_cpu]) + 128
      task_memory      = sum([for c in var.ecs_service_groups["server-3"].containers : var.services[c].ecs_container_memory]) + 128
      desired_count    = var.ecs_service_groups["server-3"].desired_count
      assign_public_ip = false

      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-3"
        }
      ]

      volumes = [
        for v in var.ecs_service_groups["server-3"].volumes : {
          name      = v.name
          host_path = replace(v.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)
        }
      ]

      containers = [
        for container_name in var.ecs_service_groups["server-3"].containers :
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
        for container_name in var.ecs_service_groups["server-3"].containers :
        {
          target_group_arn = module.alb.target_group_arns_map[container_name]
          container_name   = var.services[container_name].ecs_container_name_suffix
          container_port   = var.services[container_name].ecs_container_port_mappings[0].container_port
        }
        if var.services[container_name].alb_target_group_port != null
      ]
    }
  }

  # Hardcoded dependency: server-3 waits for server-1
  depends_on = [module.ecs_server_1]
}

# Server 2 - Depends on server-1 and server-3
module "ecs_server_2" {
  count  = var.use_eks ? 0 : 1
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = try(module.ec2[0].ecs_cluster_arn, null)
  ecs_cluster_name         = try(module.ec2[0].ecs_cluster_name, null)
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = var.ecs_service_groups["server-2"].desired_count
  service_names            = ["server-2"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"

  service_dependencies = {
    "server-2" = ["server-1", "server-3"]
  }

  has_dependencies = true

  enable_auto_scaling    = var.enable_auto_scaling
  enable_service_connect = var.enable_service_connect
  wait_for_steady_state  = true

  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    "server-2" = [
      for container_name in var.ecs_service_groups["server-2"].containers :
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
    "server-2" = {
      task_cpu         = sum([for c in var.ecs_service_groups["server-2"].containers : var.services[c].ecs_container_cpu]) + 128
      task_memory      = sum([for c in var.ecs_service_groups["server-2"].containers : var.services[c].ecs_container_memory]) + 128
      desired_count    = var.ecs_service_groups["server-2"].desired_count
      assign_public_ip = false

      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-2"
        }
      ]

      volumes = [
        for v in var.ecs_service_groups["server-2"].volumes : {
          name      = v.name
          host_path = replace(v.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)
        }
      ]

      containers = [
        for container_name in var.ecs_service_groups["server-2"].containers :
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
        for container_name in var.ecs_service_groups["server-2"].containers :
        {
          target_group_arn = module.alb.target_group_arns_map[container_name]
          container_name   = var.services[container_name].ecs_container_name_suffix
          container_port   = var.services[container_name].ecs_container_port_mappings[0].container_port
        }
        if var.services[container_name].alb_target_group_port != null
      ]
    }
  }

  # Hardcoded dependency: server-2 waits for server-1 AND server-3
  depends_on = [module.ecs_server_1, module.ecs_server_3]
}
