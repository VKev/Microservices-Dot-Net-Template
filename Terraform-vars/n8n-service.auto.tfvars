# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

services = {
  n8n = {
    alb_target_group_port     = null
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
    alb_listener_rule_priority = null
    alb_listener_rule_conditions = [
      {
        path_pattern = {
          values = [
            "/n8n",
            "/n8n/*"
          ]
        }
      }
    ]
    ecs_service_connect_dns_name       = "n8n"
    ecs_service_connect_discovery_name = "n8n"
    ecs_service_connect_port_name      = "n8n"
    ecs_container_name_suffix          = "n8n"
    ecs_container_image_repository_url = "your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/n8nio/n8n"
    ecs_container_image_tag            = "latest"
    ecs_container_cpu                  = 512
    ecs_container_memory               = 512
    ecs_container_essential            = true
    ecs_container_port_mappings = [
      {
        container_port = 5678
        host_port      = 0
        protocol       = "tcp"
        name           = "n8n"
      }
    ]
    ecs_environment_variables = [
      {
        name  = "N8N_HOST"
        value = "0.0.0.0"
      },
      {
        name  = "N8N_PORT"
        value = "5678"
      },
      {
        name  = "N8N_PROTOCOL"
        value = "http"
      },
      {
        name  = "N8N_SECURE_COOKIE"
        value = "false"
      },
      {
        name  = "N8N_PATH"
        value = "/n8n/"
      },
      {
        name  = "N8N_DB_TYPE"
        value = "postgresdb"
      },
      {
        name  = "N8N_DB_POSTGRESDB_HOST"
        value = "TERRAFORM_RDS_HOST_USER_N8NDB"
      },
      {
        name  = "N8N_DB_POSTGRESDB_PORT"
        value = "TERRAFORM_RDS_PORT_USER_N8NDB"
      },
      {
        name  = "N8N_DB_POSTGRESDB_DATABASE"
        value = "TERRAFORM_RDS_DB_USER_N8NDB"
      },
      {
        name  = "N8N_DB_POSTGRESDB_USER"
        value = "TERRAFORM_RDS_USERNAME_USER_N8NDB"
      },
      {
        name  = "N8N_DB_POSTGRESDB_PASSWORD"
        value = "TERRAFORM_RDS_PASSWORD_USER_N8NDB"
      },
      {
        name  = "GENERIC_TIMEZONE"
        value = "Asia/Ho_Chi_Minh"
      },
      {
        name  = "TZ"
        value = "Asia/Ho_Chi_Minh"
      },
      {
        name  = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
        value = "true"
      },
      {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "false"
      },
      {
        name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
        value = "false"
      },
      {
        name  = "N8N_TEMPLATES_ENABLED"
        value = "false"
      },
      {
        name  = "N8N_METRICS"
        value = "true"
      },
      {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      },
      {
        name  = "NODE_OPTIONS"
        value = "--max-old-space-size=768"
      },
      {
        name  = "N8N_EDITOR_BASE_URL"
        value = "TERRAFORM_PUBLIC_ENDPOINT/n8n/"
      },
      {
        name  = "WEBHOOK_URL"
        value = "TERRAFORM_PUBLIC_ENDPOINT/n8n/"
      },
      {
        name  = "VUE_APP_URL_BASE_API"
        value = "TERRAFORM_PUBLIC_ENDPOINT/n8n/"
      }
    ]
    ecs_container_health_check = {
      command = [
        "CMD-SHELL",
        "node -e \"http=require('http');http.get('http://localhost:5678/healthz',res=>{process.exit((res.statusCode>=200&&res.statusCode<400)?0:1)}).on('error',()=>process.exit(1))\""
      ]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    depends_on = []
  }
}
