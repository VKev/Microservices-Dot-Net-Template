# ECS Module - Server-3 (n8n automation + reverse proxy)
module "ecs_server3" {
  count  = var.use_eks ? 0 : 1
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = module.vpc.public_subnet_ids
  ecs_cluster_id           = try(module.ec2[0].ecs_cluster_arn, null)
  ecs_cluster_name         = try(module.ec2[0].ecs_cluster_name, null)
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = true
  desired_count            = 1
  service_names            = ["server-3"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies     = {}
  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_connect   = var.enable_service_connect
  wait_for_steady_state    = true

  # Pass shared resources
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    server-3 = [
      {
        # Publish n8n automation to namespace
        port_name      = var.services["n8n"].ecs_service_connect_port_name
        discovery_name = var.services["n8n"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["n8n"].ecs_service_connect_dns_name
            port     = var.services["n8n"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
    ]
  }

  service_definitions = {
    server-3 = {
      task_cpu = var.services["n8n"].ecs_container_cpu + 64
      task_memory = var.services["n8n"].ecs_container_memory + 64
      desired_count    = 1
      assign_public_ip = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-3"
        }
      ]

      containers = [
        {
          # n8n automation - uses Postgres DB instead of local volume
          name                 = "n8n"
          image_repository_url = var.services["n8n"].ecs_container_image_repository_url
          image_tag            = var.services["n8n"].ecs_container_image_tag
          cpu                  = var.services["n8n"].ecs_container_cpu
          memory               = var.services["n8n"].ecs_container_memory
          essential            = var.services["n8n"].ecs_container_essential
          port_mappings        = var.services["n8n"].ecs_container_port_mappings
          environment_variables = concat(
            [
              for env_var in var.services["n8n"].ecs_environment_variables :
              merge(env_var, {
                value = can(element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0)) ? replace(
                  env_var.value,
                  element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0),
                  lookup(local.rds_placeholder_map, element(regexall("TERRAFORM_RDS_[A-Z0-9_]+", env_var.value), 0), env_var.value)
                ) : env_var.value
              })
            ],
            [
              {
                name  = "N8N_EDITOR_BASE_URL"
                value = "${local.public_endpoint}/n8n/"
              },
              {
                name  = "WEBHOOK_URL"
                value = "${local.public_endpoint}/n8n/"
              },
              {
                name  = "VUE_APP_URL_BASE_API"
                value = "${local.public_endpoint}/n8n/"
              }
            ]
          )
          health_check = {
            command     = var.services["n8n"].ecs_container_health_check.command
            interval    = var.services["n8n"].ecs_container_health_check.interval
            timeout     = var.services["n8n"].ecs_container_health_check.timeout
            retries     = var.services["n8n"].ecs_container_health_check.retries
            startPeriod = var.services["n8n"].ecs_container_health_check.startPeriod
          }
          depends_on = []
        },
        {
          # nginx reverse proxy to expose n8n under /n8n via ALB
          name                 = "n8n-proxy"
          image_repository_url = "docker.io/library/nginx"
          image_tag            = "1.27-alpine"
          cpu                  = 64
          memory               = 128
          essential            = true
          port_mappings = [
            {
              container_port = 8088
              host_port      = 0
              protocol       = "tcp"
              name           = "n8n-proxy"
            }
          ]
          health_check = {
            command     = ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8088/n8n/healthz || exit 1"]
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

    # Set real IP from CloudFront/ALB (support ${local.n8n_proxy_depth} proxy hops)
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
          depends_on = ["n8n"]
        }
      ]

      target_groups = [
        {
          # n8n HTTP exposure via ALB
          target_group_arn = module.alb.target_group_arns_map["n8n"]
          container_name   = "n8n-proxy"
          container_port   = 8088
        }
      ]
    }
}
}
