locals {
  service_definitions_nonsensitive = try(nonsensitive(var.service_definitions), var.service_definitions)

  service_name_map = { for name in var.service_names : name => name }

  autoscaling_settings = {
    for service_name, cfg in var.autoscaling_settings :
    service_name => {
      max_capacity        = cfg.max_capacity
      min_capacity        = cfg.min_capacity
      cpu_target_value    = cfg.cpu_target_value
      memory_target_value = cfg.memory_target_value
    }
    if var.enable_auto_scaling && contains(var.service_names, service_name)
  }

  normalized_services = {
    for service_name, service in local.service_definitions_nonsensitive :
    service_name => {
      task_cpu                           = lookup(service, "task_cpu", sum([for c in service.containers : c.cpu]))
      task_memory                        = lookup(service, "task_memory", sum([for c in service.containers : c.memory]))
      desired_count                      = lookup(service, "desired_count", var.desired_count)
      assign_public_ip                   = coalesce(lookup(service, "assign_public_ip", null), var.assign_public_ip)
      enable_auto_scaling                = coalesce(lookup(service, "enable_auto_scaling", null), var.enable_auto_scaling)
      max_capacity                       = lookup(service, "max_capacity", var.max_capacity)
      min_capacity                       = lookup(service, "min_capacity", var.min_capacity)
      cpu_target_value                   = lookup(service, "cpu_target_value", var.cpu_target_value)
      memory_target_value                = lookup(service, "memory_target_value", var.memory_target_value)
      deployment_maximum_percent         = lookup(service, "deployment_maximum_percent", 200)
      deployment_minimum_healthy_percent = lookup(service, "deployment_minimum_healthy_percent", 50)
      placement_constraints              = lookup(service, "placement_constraints", [])
      target_groups                      = lookup(service, "target_groups", [])
      volumes                            = lookup(service, "volumes", [])
      containers = [
        for container in service.containers : merge(
          container,
          {
            environment_variables = lookup(container, "environment_variables", [])
            depends_on = [
              for dep in lookup(container, "depends_on", []) : dep
              if dep != container.name && contains([for c in service.containers : c.name], dep)
            ]
            essential = lookup(container, "essential", true)
            port_mappings = [
              for pm in lookup(container, "port_mappings", []) : merge(
                {
                  container_port = pm.container_port
                  host_port      = lookup(pm, "host_port", pm.container_port)
                  protocol       = lookup(pm, "protocol", "tcp")
                },
                lookup(pm, "name", null) != null ? { name = pm.name } : {},
                lookup(pm, "app_protocol", null) != null ? { app_protocol = pm.app_protocol } : {}
              )
            ]
            mount_points = [
              for mp in lookup(container, "mount_points", []) : {
                source_volume  = mp.source_volume
                container_path = mp.container_path
                read_only      = lookup(mp, "read_only", false)
              }
            ]
          }
        )
      ]
    }
  }


}

resource "aws_ecs_task_definition" "this" {
  for_each = local.service_name_map

  family                   = "${var.project_name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = tostring(local.normalized_services[each.key].task_cpu)
  memory                   = tostring(local.normalized_services[each.key].task_memory)

  task_role_arn      = var.shared_task_role_arn
  execution_role_arn = var.shared_execution_role_arn

  container_definitions = jsonencode([
    for c in local.normalized_services[each.key].containers : merge(
      {
        name      = c.name
        image     = "${c.image_repository_url}:${c.image_tag}"
        cpu       = c.cpu
        memory    = c.memory
        essential = c.essential

        portMappings = [
          for pm in c.port_mappings : merge(
            {
              containerPort = pm.container_port
              hostPort      = coalesce(try(pm.host_port == 0 ? null : pm.host_port, null), pm.container_port)
              protocol      = try(pm.protocol, "tcp")
            },
            try(pm.name, null) != null ? { name = pm.name } : {},
            try(pm.app_protocol, null) != null ? { appProtocol = pm.app_protocol } : {}
          )
        ]

        environment = [
          for env_var in c.environment_variables : {
            name  = env_var.name
            value = env_var.value
          }
        ]

        mountPoints = [
          for mp in c.mount_points : {
            containerPath = mp.container_path
            sourceVolume  = mp.source_volume
            readOnly      = mp.read_only
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = var.shared_log_group_name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "ecs/${c.name}"
          }
        }
      },
      lookup(c, "command", null) != null ? {
        command = c.command
      } : {},
      lookup(c, "health_check", null) != null ? {
        healthCheck = {
          command     = c.health_check.command
          interval    = c.health_check.interval
          timeout     = c.health_check.timeout
          retries     = c.health_check.retries
          startPeriod = c.health_check.startPeriod
        }
      } : {},
      length(c.depends_on) > 0 ? {
        dependsOn = [
          for dep in c.depends_on : {
            containerName = dep
            condition     = "HEALTHY"
          }
        ]
      } : {}
    )
  ])

  dynamic "volume" {
    for_each = local.normalized_services[each.key].volumes
    content {
      name      = volume.value.name
      host_path = try(volume.value.host_path, null)
    }
  }


}

resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each = local.autoscaling_settings

  name               = "${var.project_name}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each = local.autoscaling_settings

  name               = "${var.project_name}-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = each.value.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
