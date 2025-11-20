# ECS Module - Server-1 Split (User+RabbitMQ and Redis as separate tasks)
module "ecs_server1" {
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = module.ec2.ecs_cluster_arn
  ecs_cluster_name         = module.ec2.ecs_cluster_name
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = 1
  service_names            = ["server-1a", "server-1b"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies     = {}
  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_connect   = var.enable_service_connect
  wait_for_steady_state    = true

  # Pass shared resources
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    server-1a = [
      {
        port_name      = var.services["user"].ecs_service_connect_port_name
        discovery_name = var.services["user"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["user"].ecs_service_connect_dns_name
            port     = var.services["user"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["rabbitmq"].ecs_service_connect_port_name
        discovery_name = var.services["rabbitmq"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["rabbitmq"].ecs_service_connect_dns_name
            port     = var.services["rabbitmq"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
    ]
    server-1b = [
      {
        port_name      = var.services["redis"].ecs_service_connect_port_name
        discovery_name = var.services["redis"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["redis"].ecs_service_connect_dns_name
            port     = var.services["redis"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
    ]
  }

  service_definitions = {
    server-1a = {
      task_cpu = (
        var.services["rabbitmq"].ecs_container_cpu +
        var.services["user"].ecs_container_cpu +
        64
      )
      task_memory = (
        var.services["rabbitmq"].ecs_container_memory +
        var.services["user"].ecs_container_memory +
        64
      )
      desired_count    = 1
      assign_public_ip = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-1"
        }
      ]

      volumes = [
        {
          name      = "rabbitmq-data"
          host_path = "/var/lib/${var.project_name}/rabbitmq"
        }
      ]

      containers = [
        {
          # RabbitMQ - deployed first as dependency
          name                  = "rabbitmq"
          image_repository_url  = var.services["rabbitmq"].ecs_container_image_repository_url
          image_tag             = var.services["rabbitmq"].ecs_container_image_tag
          cpu                   = var.services["rabbitmq"].ecs_container_cpu
          memory                = var.services["rabbitmq"].ecs_container_memory
          essential             = var.services["rabbitmq"].ecs_container_essential
          port_mappings         = var.services["rabbitmq"].ecs_container_port_mappings
          environment_variables = var.services["rabbitmq"].ecs_environment_variables
          health_check = {
            command     = var.services["rabbitmq"].ecs_container_health_check.command
            interval    = var.services["rabbitmq"].ecs_container_health_check.interval
            timeout     = var.services["rabbitmq"].ecs_container_health_check.timeout
            retries     = var.services["rabbitmq"].ecs_container_health_check.retries
            startPeriod = var.services["rabbitmq"].ecs_container_health_check.startPeriod
          }
          mount_points = [
            {
              source_volume  = "rabbitmq-data"
              container_path = "/var/lib/rabbitmq"
            }
          ]
          depends_on = []
        },
        {
          # User microservice - depends on RabbitMQ
          name                 = "user-microservice"
          image_repository_url = var.services["user"].ecs_container_image_repository_url
          image_tag            = var.services["user"].ecs_container_image_tag
          cpu                  = var.services["user"].ecs_container_cpu
          memory               = var.services["user"].ecs_container_memory
          essential            = var.services["user"].ecs_container_essential
          port_mappings        = var.services["user"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["user"].ecs_environment_variables :
            merge(env_var, {
              value = can(element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0)) ? replace(
                env_var.value,
                element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0),
                lookup(local.rds_placeholder_map, element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0), env_var.value)
              ) : env_var.value
            })
          ]
          health_check = {
            command     = var.services["user"].ecs_container_health_check.command
            interval    = var.services["user"].ecs_container_health_check.interval
            timeout     = var.services["user"].ecs_container_health_check.timeout
            retries     = var.services["user"].ecs_container_health_check.retries
            startPeriod = var.services["user"].ecs_container_health_check.startPeriod
          }
          depends_on = ["rabbitmq"]
        }
      ]

      target_groups = []
    }

    server-1b = {
      task_cpu         = (var.services["redis"].ecs_container_cpu + 64)
      task_memory      = (var.services["redis"].ecs_container_memory + 64)
      desired_count    = 1
      assign_public_ip = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-1"
        }
      ]

      volumes = [
        {
          name      = "redis-data"
          host_path = "/var/lib/${var.project_name}/redis"
        }
      ]

      containers = [
        {
          # Redis
          name                  = "redis"
          image_repository_url  = var.services["redis"].ecs_container_image_repository_url
          image_tag             = var.services["redis"].ecs_container_image_tag
          cpu                   = var.services["redis"].ecs_container_cpu
          memory                = var.services["redis"].ecs_container_memory
          essential             = var.services["redis"].ecs_container_essential
          port_mappings         = var.services["redis"].ecs_container_port_mappings
          environment_variables = var.services["redis"].ecs_environment_variables
          command               = lookup(var.services["redis"], "command", null)
          health_check = {
            command     = var.services["redis"].ecs_container_health_check.command
            interval    = var.services["redis"].ecs_container_health_check.interval
            timeout     = var.services["redis"].ecs_container_health_check.timeout
            retries     = var.services["redis"].ecs_container_health_check.retries
            startPeriod = var.services["redis"].ecs_container_health_check.startPeriod
          }
          mount_points = [
            {
              source_volume  = "redis-data"
              container_path = "/data"
            }
          ]
          depends_on = []
        }
      ]

      target_groups = []
    }
  }

  depends_on = [module.ec2]
}
