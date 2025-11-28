services = {
  nginx = {
    # ECS service for the n8n reverse proxy
    alb_target_group_port     = 8088
    alb_target_group_protocol = "HTTP"
    alb_target_group_type     = "ip"
    alb_health_check = {
      enabled             = true
      path                = "/n8n/healthz"
      port                = "traffic-port"
      protocol            = "HTTP"
      matcher             = "200-399"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority   = 16
    alb_listener_rule_conditions = []

    ecs_service_connect_dns_name       = "n8n-proxy"
    ecs_service_connect_discovery_name = "n8n-proxy"
    ecs_service_connect_port_name      = "n8n-proxy"

    ecs_container_name_suffix          = "n8n-proxy"
    ecs_container_image_repository_url = "936910352865.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/nginx"
    ecs_container_image_tag            = "1.27-alpine"
    ecs_container_cpu                  = 64
    ecs_container_memory               = 128
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 8088
        host_port      = 0
        protocol       = "tcp"
        name           = "n8n-proxy"
      }
    ]

    ecs_environment_variables = []

    ecs_container_health_check = {
      command     = ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8088/n8n/healthz || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    depends_on = ["n8n"]
  }
}
