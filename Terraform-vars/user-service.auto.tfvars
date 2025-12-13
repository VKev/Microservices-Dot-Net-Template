# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

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
          values = [
            "/api/user/*"
          ]
        }
      }
    ]
    ecs_service_connect_dns_name       = "user-service"
    ecs_service_connect_discovery_name = "user-service"
    ecs_service_connect_port_name      = "user"
    ecs_container_name_suffix          = "user"
    ecs_container_image_repository_url = "your-aws-id.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr"
    ecs_container_image_tag            = "User.Microservice-latest"
    ecs_container_cpu                  = 384
    ecs_container_memory               = 256
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
      {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      },
      {
        name  = "ASPNETCORE_URLS"
        value = "http://+:5002"
      },
      {
        name  = "Database__Host"
        value = "TERRAFORM_RDS_HOST_USER_DEFAULTDB"
      },
      {
        name  = "Database__Port"
        value = "TERRAFORM_RDS_PORT_USER_DEFAULTDB"
      },
      {
        name  = "Database__Name"
        value = "TERRAFORM_RDS_DB_USER_DEFAULTDB"
      },
      {
        name  = "Database__Username"
        value = "TERRAFORM_RDS_USERNAME_USER_DEFAULTDB"
      },
      {
        name  = "Database__Password"
        value = "TERRAFORM_RDS_PASSWORD_USER_DEFAULTDB"
      },
      {
        name  = "Database__Provider"
        value = "TERRAFORM_RDS_PROVIDER_USER_DEFAULTDB"
      },
      {
        name  = "Database__SslMode"
        value = "TERRAFORM_RDS_SSLMODE_USER_DEFAULTDB"
      },
      {
        name  = "RabbitMq__Host"
        value = "localhost"
      },
      {
        name  = "RabbitMq__Port"
        value = "5672"
      },
      {
        name  = "RabbitMq__Username"
        value = "rabbitmq"
      },
      {
        name  = "RabbitMq__Password"
        value = "<REDACTED>"
      },
      {
        name  = "Redis__Host"
        value = "localhost"
      },
      {
        name  = "Redis__Password"
        value = "<REDACTED>"
      },
      {
        name  = "Redis__Port"
        value = "6379"
      },
      {
        name  = "Jwt__SecretKey"
        value = "<REDACTED>"
      },
      {
        name  = "Jwt__Issuer"
        value = "UserMicroservice"
      },
      {
        name  = "Jwt__Audience"
        value = "MicroservicesApp"
      },
      {
        name  = "Jwt__ExpirationMinutes"
        value = "60"
      },
      {
        name  = "AutoApply__Migrations"
        value = "true"
      },
      {
        name  = "Cors__AllowedOrigins__0"
        value = "http://localhost:5173"
      },
      {
        name  = "Cors__AllowedOrigins__1"
        value = "https://your-frontend.example.com"
      },
      {
        name  = "Cors__AllowedOrigins__2"
        value = "http://localhost:2406"
      }
    ]
    ecs_container_health_check = {
      command = [
        "CMD-SHELL",
        "curl -f http://localhost:5002/health || exit 1"
      ]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    depends_on = [
      "rabbitmq",
      "redis"
    ]
  }
}
