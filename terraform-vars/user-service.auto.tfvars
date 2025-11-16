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
    ecs_container_image_repository_url = "936910352865.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr"
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
      { name = "ASPNETCORE_URLS", value = "http://+:5002" },
      { name = "Database__Host", value = "pg-2-database25812.g.aivencloud.com" },
      { name = "Database__Port", value = "19217" },
      { name = "Database__Name", value = "userdb" },
      { name = "Database__Username", value = "avnadmin" },
      { name = "Database__Password", value = "AVNS_vsIotPLRrxJUhcJlM0m" },
      { name = "Database__Provider", value = "postgres" },
      { name = "Database__SslMode", value = "Require" },
      { name = "RabbitMq__Host", value = "rabbitmq" }, # ECS Service Connect DNS
      { name = "RabbitMq__Port", value = "5672" },
      { name = "RabbitMq__Username", value = "rabbitmq" },
      { name = "RabbitMq__Password", value = "0Kg04Rq08!" },
      { name = "Redis__Host", value = "redis" },
      { name = "Redis__Password", value = "0Kg04Rs05!" },
      { name = "Redis__Port", value = "6379" },
      { name = "Jwt__SecretKey", value = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()" },
      { name = "Jwt__Issuer", value = "UserMicroservice" },
      { name = "Jwt__Audience", value = "MicroservicesApp" },
      { name = "Jwt__ExpirationMinutes", value = "60" },
      { name = "Smtp__Host", value = "smtp.example.com" },
      { name = "Smtp__Port", value = "587" },
      { name = "Smtp__Secure", value = "true" },
      { name = "Smtp__User", value = "" },
      { name = "Smtp__Pass", value = "" },
      { name = "Smtp__From__Name", value = "User Service" },
      { name = "Smtp__From__Email", value = "no-reply@example.com" },
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
