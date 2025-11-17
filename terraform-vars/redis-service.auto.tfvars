services = {
  redis = {
    alb_target_group_port     = 6379
    alb_target_group_protocol = "TCP"
    alb_target_group_type     = "instance"
    alb_health_check = {
      enabled             = false
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTP"
      matcher             = "200"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority   = 13
    alb_listener_rule_conditions = []

    ecs_service_connect_dns_name       = "redis"
    ecs_service_connect_discovery_name = "redis"
    ecs_service_connect_port_name      = "redis"
    ecs_container_name_suffix          = "redis"
    ecs_container_image_repository_url = "936910352865.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/redis"
    ecs_container_image_tag            = "alpine"
    ecs_container_cpu                  = 160
    ecs_container_memory               = 160
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 6379
        host_port      = 0
        protocol       = "tcp"
        name           = "redis"
      }
    ]

    ecs_environment_variables = [
      { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" }
    ]

    command = ["redis-server", "--requirepass", "0Kg04Rs05!"]

    ecs_container_health_check = {
      command     = ["CMD-SHELL", "redis-cli -a 0Kg04Rs05! ping || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 5
      startPeriod = 30
    }
    depends_on = []
  }
}
