services = {
  user = {
    alb_target_group_port     = 5002
    alb_target_group_protocol = "HTTP"
    alb_target_group_type     = "ip"
    alb_health_check = {
      enabled             = true
      path                = "/health"
      port                = "traffic-port"
      protocol            = "HTTP"
      matcher             = "200"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority = 11
    alb_listener_rule_conditions = [
      {
        path_pattern = {
          values = ["/api/user/*"]
        }
      }
    ]
    ecs_service_connect_dns_name       = "user-service"
    ecs_service_connect_discovery_name = "user-service"
    ecs_service_connect_port_name      = "user"
    ecs_container_name_suffix          = "microservice"
    ecs_container_image_repository_url = "936910352865.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-ecr"
    ecs_container_image_tag            = "User.Microservice-latest"
    ecs_container_cpu                  = 120
    ecs_container_memory               = 120
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 5002
        host_port      = 0
        protocol       = "tcp"
        name           = "user"
      }
    ]

    ecs_environment_variables = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "DATABASE_HOST", value = "pg-2-database25812.g.aivencloud.com" },
      { name = "DATABASE_PORT", value = "19217" },
      { name = "DATABASE_NAME", value = "userdb" },
      { name = "DATABASE_USERNAME", value = "avnadmin" },
      { name = "DATABASE_PASSWORD", value = "AVNS_vsIotPLRrxJUhcJlM0m" },
      { name = "DATABASE_SSLMODE", value = "Require" },
      { name = "ASPNETCORE_URLS", value = "http://+:5002" },
      { name = "RABBITMQ_HOST", value = "rabbitmq" },
      { name = "RABBITMQ_PORT", value = "5672" },
      { name = "RABBITMQ_USERNAME", value = "rabbitmq" },
      { name = "RABBITMQ_PASSWORD", value = "0Kg04Rq08!" },
      { name = "REDIS_HOST", value = "redis" },
      { name = "REDIS_PASSWORD", value = "0Kg04Rs05!" },
      { name = "REDIS_PORT", value = "6379" },
      { name = "Jwt__SecretKey", value = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()" },
      { name = "Jwt__Issuer", value = "UserMicroservice" },
      { name = "Jwt__Audience", value = "MicroservicesApp" },
      { name = "Jwt__ExpirationMinutes", value = "60" },
      { name = "SMTP_HOST", value = "smtp.example.com" },
      { name = "SMTP_PORT", value = "587" },
      { name = "SMTP_SECURE", value = "true" },
      { name = "SMTP_USER", value = "" },
      { name = "SMTP_PASS", value = "" },
      { name = "SMTP_FROM_NAME", value = "User Service" },
      { name = "SMTP_FROM_EMAIL", value = "no-reply@example.com" },
      { name = "AUTO_APPLY_MIGRATIONS", value = "true" },
      { name = "Cors__AllowedOrigins__0", value = "http://localhost:5173" },
      { name = "Cors__AllowedOrigins__1", value = "https://your-frontend.example.com" },
      { name = "Cors__AllowedOrigins__2", value = "http://localhost:2406" },
      { name = "ConnectionStrings__DefaultConnection", value = "Host=pg-2-database25812.g.aivencloud.com;Port=19217;Database=userdb;Username=avnadmin;Password=AVNS_vsIotPLRrxJUhcJlM0m;Ssl Mode=Require;" }
    ]

    ecs_container_health_check = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5002/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    depends_on = ["rabbitmq", "redis"]
  }
}
