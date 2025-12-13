# This file is automatically sanitized.
# Run scripts/sanitize_tfvars.py after editing real tfvars.

services = {
  nginx = {
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
    alb_listener_rule_priority = 16
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
    ecs_service_connect_dns_name       = "n8n-proxy"
    ecs_service_connect_discovery_name = "n8n-proxy"
    ecs_service_connect_port_name      = "n8n-proxy"
    ecs_container_name_suffix          = "n8n-proxy"
    ecs_container_image_repository_url = "your-aws-id.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/nginx"
    ecs_container_image_tag            = "1.27-alpine"
    ecs_container_cpu                  = 64
    ecs_container_memory               = 64
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
      command = [
        "CMD-SHELL",
        "wget -q --spider http://127.0.0.1:8088/n8n/healthz || exit 1"
      ]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    command = [
      "sh",
      "-c",
      <<-EOT
      cat <<'EOF' > /etc/nginx/conf.d/default.conf
      server {
          listen 8088;
          server_name _;
          client_max_body_size 50m;
      
          # Set real IP from CloudFront/ALB (support TERRAFORM_N8N_PROXY_DEPTH proxy hops)
          set_real_ip_from 10.0.0.0/8;
          real_ip_header X-Forwarded-For;
          real_ip_recursive on;
      
          location = /n8n {
              return 301 /n8n/;
          }
      
          location /n8n/ {
              proxy_pass http://127.0.0.1:5678/;
              proxy_http_version 1.1;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Prefix /n8n/;
              proxy_set_header X-Forwarded-Uri $request_uri;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_redirect off;
              proxy_buffering off;
          }
      
          location / {
              return 404;
          }
      }
      EOF
      nginx -g 'daemon off;'
      EOT
    ]
    depends_on = [
      "n8n"
    ]
  }
}
