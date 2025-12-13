# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

services = {
  guest = {
    alb_target_group_port = 5001
    alb_target_group_protocol = "HTTP"
    alb_target_group_type = "ip"
    alb_health_check = {
      enabled = true
      path = "/health"
      port = "traffic-port"
      protocol = "HTTP"
      matcher = "200"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 3
    }
    alb_listener_rule_priority = 12
    alb_listener_rule_conditions = [
      {
              path_pattern = {
                values = [
                  "/api/guest",
                  "/api/guest/*"
                ]
              }
            }
    ]
    ecs_service_connect_dns_name = "guest-service"
    ecs_service_connect_discovery_name = "guest-service"
    ecs_service_connect_port_name = "guest"
    ecs_container_name_suffix = "guest"
    ecs_container_image_repository_url = "936910352865.dkr.ecr.us-east-1.amazonaws.com/vkev2406-infrastructure-khanghv2406-infrastructure-khanghv2406-ecr"
    ecs_container_image_tag = "Guest.Microservice-latest"
    ecs_container_cpu = 512
    ecs_container_memory = 256
    ecs_container_essential = true
    ecs_container_port_mappings = [
      {
              container_port = 5001
              host_port = 0
              protocol = "tcp"
              name = "guest"
            }
    ]
    ecs_environment_variables = [
      {
              name = "ASPNETCORE_ENVIRONMENT"
              value = "Production"
            },
      {
              name = "ASPNETCORE_URLS"
              value = "http://+:5001"
            },
      {
              name = "Database__Host"
              value = "TERRAFORM_RDS_HOST_GUEST_DEFAULTDB"
            },
      {
              name = "Database__Port"
              value = "TERRAFORM_RDS_PORT_GUEST_DEFAULTDB"
            },
      {
              name = "Database__Name"
              value = "TERRAFORM_RDS_DB_GUEST_DEFAULTDB"
            },
      {
              name = "Database__Username"
              value = "TERRAFORM_RDS_USERNAME_GUEST_DEFAULTDB"
            },
      {
              name = "Database__Password"
              value = "TERRAFORM_RDS_PASSWORD_GUEST_DEFAULTDB"
            },
      {
              name = "Database__Provider"
              value = "TERRAFORM_RDS_PROVIDER_GUEST_DEFAULTDB"
            },
      {
              name = "RabbitMq__Host"
              value = "rabbitmq"
            },
      {
              name = "RabbitMq__Port"
              value = "5672"
            },
      {
              name = "RabbitMq__Username"
              value = "rabbitmq"
            },
      {
              name = "RabbitMq__Password"
              value = "<REDACTED>"
            },
      {
              name = "Redis__Host"
              value = "redis"
            },
      {
              name = "Redis__Password"
              value = "<REDACTED>"
            },
      {
              name = "Redis__Port"
              value = "6379"
            },
      {
              name = "Jwt__SecretKey"
              value = "<REDACTED>"
            },
      {
              name = "Jwt__Issuer"
              value = "UserMicroservice"
            },
      {
              name = "Jwt__Audience"
              value = "MicroservicesApp"
            },
      {
              name = "Jwt__ExpirationMinutes"
              value = "60"
            },
      {
              name = "AutoApply__Migrations"
              value = "true"
            }
    ]
    ecs_container_health_check = {
      command = [
        "CMD-SHELL",
        "curl -f http://localhost:5001/health || exit 1"
      ]
      interval = 30
      timeout = 5
      retries = 3
      startPeriod = 10
    }
    depends_on = []
  }
}
