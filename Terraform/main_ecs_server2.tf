# ECS Module - Server-2 (API Gateway + Guest microservice)
# Deploys after server-1 to ensure service discovery endpoints are available
module "ecs_server2" {
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
  desired_count            = 1
  service_names            = ["server-2"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies = {
    server-2 = ["server-1"]
  }
  enable_auto_scaling    = var.enable_auto_scaling
  enable_service_connect = var.enable_service_connect
  wait_for_steady_state  = true

  # Pass shared resources (same as server-1)
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  # Use existing namespace created above
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    server-2 = [
      {
        # Publish guest-service to namespace
        port_name      = var.services["guest"].ecs_service_connect_port_name
        discovery_name = var.services["guest"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["guest"].ecs_service_connect_dns_name
            port     = var.services["guest"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        # Publish API Gateway to namespace
        port_name      = var.services["apigateway"].ecs_service_connect_port_name
        discovery_name = var.services["apigateway"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["apigateway"].ecs_service_connect_dns_name
            port     = var.services["apigateway"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      # Note: User, RabbitMQ, Redis auto-discovered via Service Connect namespace
    ]
  }

  service_definitions = {
    server-2 = {
      task_cpu = (
        var.services["guest"].ecs_container_cpu +
        var.services["apigateway"].ecs_container_cpu +
        64
      )
      task_memory = (
        var.services["guest"].ecs_container_memory +
        var.services["apigateway"].ecs_container_memory +
        64
      )
      desired_count       = 1
      assign_public_ip    = false
      enable_auto_scaling = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-2"
        }
      ]

      containers = [
        {
          # Guest microservice - deployed first as dependency for API Gateway
          name                 = "guest-microservice"
          image_repository_url = var.services["guest"].ecs_container_image_repository_url
          image_tag            = var.services["guest"].ecs_container_image_tag
          cpu                  = var.services["guest"].ecs_container_cpu
          memory               = var.services["guest"].ecs_container_memory
          essential            = var.services["guest"].ecs_container_essential
          port_mappings        = var.services["guest"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["guest"].ecs_environment_variables :
            merge(env_var, {
              value = can(element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0)) ? replace(
                env_var.value,
                element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0),
                lookup(local.rds_placeholder_map, element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0), env_var.value)
              ) : env_var.value
            })
          ]
          health_check = {
            command     = var.services["guest"].ecs_container_health_check.command
            interval    = var.services["guest"].ecs_container_health_check.interval
            timeout     = var.services["guest"].ecs_container_health_check.timeout
            retries     = var.services["guest"].ecs_container_health_check.retries
            startPeriod = var.services["guest"].ecs_container_health_check.startPeriod
          }
          depends_on = []
        },
        {
          # API Gateway - depends on Guest microservice
          name                 = "api-gateway"
          image_repository_url = var.services["apigateway"].ecs_container_image_repository_url
          image_tag            = var.services["apigateway"].ecs_container_image_tag
          cpu                  = var.services["apigateway"].ecs_container_cpu
          memory               = var.services["apigateway"].ecs_container_memory
          essential            = var.services["apigateway"].ecs_container_essential
          port_mappings        = var.services["apigateway"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["apigateway"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["apigateway"].ecs_container_health_check.command
            interval    = var.services["apigateway"].ecs_container_health_check.interval
            timeout     = var.services["apigateway"].ecs_container_health_check.timeout
            retries     = var.services["apigateway"].ecs_container_health_check.retries
            startPeriod = var.services["apigateway"].ecs_container_health_check.startPeriod
          }
          depends_on = ["guest-microservice"]
        }
      ]

      target_groups = [
        {
          # API Gateway to ALB Target Group
          target_group_arn = module.alb.target_group_arns_map["apigateway"]
          container_name   = "api-gateway"
          container_port   = var.services["apigateway"].ecs_container_port_mappings[0].container_port
        }
      ]
    }
  }

  depends_on = var.use_eks ? [] : module.ecs_server1
}

