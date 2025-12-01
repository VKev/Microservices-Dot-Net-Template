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

resource "null_resource" "debug_service_creation" {
  for_each = local.service_name_map

  provisioner "local-exec" {
    command = "echo DEBUG: Starting creation of ECS service ${each.key} in project ${var.project_name}"
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

# Note: Namespace is created externally and passed via service_connect_namespace
# This resource is kept for backward compatibility but should not be created
resource "aws_service_discovery_private_dns_namespace" "dns_ns" {
  count       = 0 # Always disabled - use shared namespace
  name        = var.service_discovery_domain
  vpc         = var.vpc_id
  description = "Service discovery namespace for ${var.project_name}"
  tags        = { Name = "${var.project_name}-dns-namespace" }
}

resource "aws_ecs_service" "this_no_deps" {
  for_each = {
    for k, v in local.service_name_map : k => v
    if !var.has_dependencies
  }

  name                  = "${var.project_name}-${each.key}"
  cluster               = var.ecs_cluster_id
  task_definition       = aws_ecs_task_definition.this[each.key].arn
  desired_count         = local.normalized_services[each.key].desired_count
  launch_type           = "EC2"
  wait_for_steady_state = true

  network_configuration {
    assign_public_ip = local.normalized_services[each.key].assign_public_ip
    subnets          = var.task_subnet_ids
    security_groups  = [var.shared_task_sg_id]
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.instance-id"
  }
  dynamic "placement_constraints" {
    for_each = local.normalized_services[each.key].placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = lookup(placement_constraints.value, "expression", null)
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.enable_service_connect && var.service_connect_namespace != null ? [1] : []
    content {
      enabled   = true
      namespace = var.service_connect_namespace

      dynamic "service" {
        for_each = lookup(var.service_connect_services, each.key, [])
        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = try(service.value.ingress_port_override, null)

          dynamic "client_alias" {
            for_each = try(service.value.client_aliases, [])
            content {
              dns_name = client_alias.value.dns_name
              port     = client_alias.value.port
            }
          }
        }
      }
    }
  }
  dynamic "load_balancer" {
    for_each = local.normalized_services[each.key].target_groups
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_maximum_percent         = local.normalized_services[each.key].deployment_maximum_percent
  deployment_minimum_healthy_percent = local.normalized_services[each.key].deployment_minimum_healthy_percent

  lifecycle {
    ignore_changes = [desired_count]
    replace_triggered_by = [
      aws_ecs_task_definition.this[each.key].arn
    ]
  }

  tags = merge(
    { Name = "${var.project_name}-${each.key}-ecs-service" },
    {
      for dep in lookup(var.service_dependencies, each.key, []) :
      "tf_dep_${dep}" => "${var.project_name}-${dep}"
      if dep != each.key
    }
  )
}

# Wait for specific dependencies before creating each service
resource "null_resource" "wait_for_dependencies" {
  for_each = {
    for k, v in local.service_name_map : k => lookup(var.service_dependencies, k, [])
    if var.has_dependencies && length(lookup(var.service_dependencies, k, [])) > 0
  }

  # Trigger re-execution if dependencies change
  triggers = {
    dependencies = join(",", [for dep in each.value : "${var.project_name}-${dep}"])
    cluster      = var.ecs_cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      python ${path.module}/../../scripts/wait_for_services.py \
        --cluster "${var.ecs_cluster_name}" \
        --services "${join(",", [for dep in each.value : "${var.project_name}-${dep}"])}" \
        --region "${var.aws_region}" \
        --timeout 20
    EOT
  }
}

resource "aws_ecs_service" "this_with_deps" {
  for_each = {
    for k, v in local.service_name_map : k => v
    if var.has_dependencies
  }

  name                  = "${var.project_name}-${each.key}"
  cluster               = var.ecs_cluster_id
  task_definition       = aws_ecs_task_definition.this[each.key].arn
  desired_count         = local.normalized_services[each.key].desired_count
  launch_type           = "EC2"
  wait_for_steady_state = true

  network_configuration {
    assign_public_ip = local.normalized_services[each.key].assign_public_ip
    subnets          = var.task_subnet_ids
    security_groups  = [var.shared_task_sg_id]
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.instance-id"
  }
  dynamic "placement_constraints" {
    for_each = local.normalized_services[each.key].placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = lookup(placement_constraints.value, "expression", null)
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.enable_service_connect && var.service_connect_namespace != null ? [1] : []
    content {
      enabled   = true
      namespace = var.service_connect_namespace

      dynamic "service" {
        for_each = lookup(var.service_connect_services, each.key, [])
        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = try(service.value.ingress_port_override, null)

          dynamic "client_alias" {
            for_each = try(service.value.client_aliases, [])
            content {
              dns_name = client_alias.value.dns_name
              port     = client_alias.value.port
            }
          }
        }
      }
    }
  }
  dynamic "load_balancer" {
    for_each = local.normalized_services[each.key].target_groups
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_maximum_percent         = local.normalized_services[each.key].deployment_maximum_percent
  deployment_minimum_healthy_percent = local.normalized_services[each.key].deployment_minimum_healthy_percent

  lifecycle {
    ignore_changes = [desired_count]
    replace_triggered_by = [
      aws_ecs_task_definition.this[each.key].arn
    ]
  }

  tags = merge(
    { Name = "${var.project_name}-${each.key}-ecs-service" },
    {
      for dep in lookup(var.service_dependencies, each.key, []) :
      "tf_dep_${dep}" => "${var.project_name}-${dep}"
      if dep != each.key
    },
    # Create implicit dependency on THIS service's specific null_resource
    # by referencing its id (only if it exists for this service)
    length(lookup(var.service_dependencies, each.key, [])) > 0 ? {
      "tf_wait_completed" = null_resource.wait_for_dependencies[each.key].id
    } : {}
  )
}

resource "aws_appautoscaling_target" "ecs_target" {
  for_each = local.autoscaling_settings

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${try(aws_ecs_service.this_no_deps[each.key].name, aws_ecs_service.this_with_deps[each.key].name)}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
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
