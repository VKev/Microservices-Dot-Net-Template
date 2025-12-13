# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

ecs_service_groups = {
  server-1 = {
    desired_count = 1
    containers = [
      "rabbitmq",
      "redis",
      "user"
    ]
    volumes = [
      {
        name      = "rabbitmq-data"
        host_path = "/var/lib/TERRAFORM_PROJECT_NAME/rabbitmq"
      },
      {
        name      = "redis-data"
        host_path = "/var/lib/TERRAFORM_PROJECT_NAME/redis"
      }
    ]
    dependencies = []
  }
  server-3 = {
    desired_count = 1
    containers = [
      "n8n",
      "nginx"
    ]
    volumes = []
    dependencies = [
      "server-1"
    ]
  }
  server-2 = {
    desired_count = 1
    containers = [
      "guest",
      "apigateway"
    ]
    volumes = []
    dependencies = [
      "server-1",
      "server-3"
    ]
  }
}
