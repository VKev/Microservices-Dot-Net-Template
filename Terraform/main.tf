locals {
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  rabbitmq_host            = "rabbitmq"
  redis_host               = "redis"
  guest_service_host       = "guest-service"
  user_service_host        = "user-service"
  n8n_service_connect_host = var.services["n8n"].ecs_service_connect_dns_name
  n8n_service_port         = var.services.n8n.ecs_container_port_mappings[0].container_port

  # Public endpoint - use CloudFront HTTPS if enabled, otherwise ALB HTTP
  public_endpoint = var.use_cloudfront_https ? "https://${module.cloudfront[0].cloudfront_domain_name}" : "http://${module.alb.alb_dns_name}"

  # Proxy depth for n8n - CloudFront adds one more hop (CloudFront -> ALB -> Container)
  # Without CloudFront: 1 (ALB -> Container)
  # With CloudFront: 2 (CloudFront -> ALB -> Container)
  n8n_proxy_depth = var.use_cloudfront_https ? 2 : 1
}

# VPC Module
module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  public_subnet_count = 2
  private_subnet_cidr = var.private_subnet_cidr
}

# ALB Module
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  # SSL/TLS Certificate Configuration
  certificate_arn       = var.certificate_arn
  enable_https_redirect = var.enable_https_redirect

  target_groups_definition = [
    {
      # API Gateway Target Group
      name_suffix = "apigateway"
      port        = var.services["apigateway"].alb_target_group_port
      protocol    = var.services["apigateway"].alb_target_group_protocol
      target_type = var.services["apigateway"].alb_target_group_type
      health_check = {
        enabled             = true
        path                = "/api/health"
        port                = var.services["apigateway"].alb_health_check.port
        protocol            = var.services["apigateway"].alb_health_check.protocol
        matcher             = var.services["apigateway"].alb_health_check.matcher
        interval            = var.services["apigateway"].alb_health_check.interval
        timeout             = var.services["apigateway"].alb_health_check.timeout
        healthy_threshold   = var.services["apigateway"].alb_health_check.healthy_threshold
        unhealthy_threshold = var.services["apigateway"].alb_health_check.unhealthy_threshold
      }
    },
    {
      # n8n Target Group
      name_suffix = "n8n"
      port        = var.services["n8n"].alb_target_group_port
      protocol    = var.services["n8n"].alb_target_group_protocol
      target_type = var.services["n8n"].alb_target_group_type
      health_check = {
        enabled             = var.services["n8n"].alb_health_check.enabled
        path                = var.services["n8n"].alb_health_check.path
        port                = var.services["n8n"].alb_health_check.port
        protocol            = var.services["n8n"].alb_health_check.protocol
        matcher             = var.services["n8n"].alb_health_check.matcher
        interval            = var.services["n8n"].alb_health_check.interval
        timeout             = var.services["n8n"].alb_health_check.timeout
        healthy_threshold   = var.services["n8n"].alb_health_check.healthy_threshold
        unhealthy_threshold = var.services["n8n"].alb_health_check.unhealthy_threshold
      }
    }
  ]

  default_listener_action = {
    type                = "forward"
    target_group_suffix = "apigateway"
  }

  listener_rules_definition = [
    {
      priority            = var.services["n8n"].alb_listener_rule_priority
      target_group_suffix = "n8n"
      conditions          = var.services["n8n"].alb_listener_rule_conditions
    }
  ]
}

# EC2 Module
module "ec2" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_id             = module.vpc.private_subnet_id
  instance_type         = var.instance_type
  associate_public_ip   = var.associate_public_ip
  alb_security_group_id = module.alb.alb_sg_id
  container_instance_groups = {
    server-1 = {
      instance_attributes = { service_group = "server-1" }
      tags                = { ServiceGroup = "server-1" }
      user_data_extra     = <<-EOF
        mkdir -p /var/lib/${var.project_name}/rabbitmq
        mkdir -p /var/lib/${var.project_name}/redis
        chown 999:999 /var/lib/${var.project_name}/rabbitmq || true
        chown 999:999 /var/lib/${var.project_name}/redis || true
        chmod 0775 /var/lib/${var.project_name}/rabbitmq || chmod 0777 /var/lib/${var.project_name}/rabbitmq
        chmod 0775 /var/lib/${var.project_name}/redis || chmod 0777 /var/lib/${var.project_name}/redis
      EOF
    }
    server-2 = {
      instance_attributes = { service_group = "server-2" }
      tags                = { ServiceGroup = "server-2" }
      user_data_extra     = <<-EOF
        mkdir -p /var/lib/${var.project_name}/n8n
        chown 1000:1000 /var/lib/${var.project_name}/n8n || true
        chmod 0775 /var/lib/${var.project_name}/n8n || chmod 0777 /var/lib/${var.project_name}/n8n
      EOF
    }
  }

  depends_on = [module.alb]
}

# Shared ECS Resources (created once, used by all services)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ecs-task-role" }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ecs-execution-role" }
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.ecs_logs.arn}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ecr_pull" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "ecs_task_sg" {
  name_prefix = "${var.project_name}-ecs-task-sg-"
  description = "Security group for ECS tasks (awsvpc)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow inbound from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [module.alb.alb_sg_id]
  }

  ingress {
    description = "Allow intra-VPC task-to-task"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-task-sg" }
}

resource "aws_security_group_rule" "task_sg_intra_self" {
  type              = "ingress"
  description       = "Allow all traffic within ECS task SG"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_task_sg.id
  self              = true
}

resource "aws_service_discovery_private_dns_namespace" "ecs_namespace" {
  count       = var.enable_service_connect ? 1 : 0
  name        = "${var.project_name}.${var.service_discovery_domain_suffix}"
  vpc         = module.vpc.vpc_id
  description = "Service discovery namespace for ${var.project_name}"
  tags        = { Name = "${var.project_name}-dns-namespace" }
}

# ECS Module - Server-1 (User microservice + RabbitMQ + Redis)
module "ecs_server1" {
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = [module.vpc.private_subnet_id]
  ecs_cluster_id           = module.ec2.ecs_cluster_arn
  ecs_cluster_name         = module.ec2.ecs_cluster_name
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = false
  desired_count            = 1
  service_names            = ["server-1"]
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
    server-1 = [
      {
        port_name      = var.services["user"].ecs_service_connect_port_name
        discovery_name = var.services["user"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["user"].ecs_service_connect_dns_name
            port     = var.services["user"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["rabbitmq"].ecs_service_connect_port_name
        discovery_name = var.services["rabbitmq"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["rabbitmq"].ecs_service_connect_dns_name
            port     = var.services["rabbitmq"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
      {
        port_name      = var.services["redis"].ecs_service_connect_port_name
        discovery_name = var.services["redis"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["redis"].ecs_service_connect_dns_name
            port     = var.services["redis"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      # Note: API Gateway and Guest services auto-discovered via Service Connect namespace
    ]
  }

  service_definitions = {
    server-1 = {
      task_cpu         = 640
      task_memory      = 640
      desired_count    = 1
      assign_public_ip = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-1"
        }
      ]

      volumes = [
        {
          name      = "rabbitmq-data"
          host_path = "/var/lib/${var.project_name}/rabbitmq"
        },
        {
          name      = "redis-data"
          host_path = "/var/lib/${var.project_name}/redis"
        }
      ]

      containers = [
        {
          # RabbitMQ - deployed first as dependency
          name                  = "rabbitmq"
          image_repository_url  = var.services["rabbitmq"].ecs_container_image_repository_url
          image_tag             = var.services["rabbitmq"].ecs_container_image_tag
          cpu                   = var.services["rabbitmq"].ecs_container_cpu
          memory                = var.services["rabbitmq"].ecs_container_memory
          essential             = var.services["rabbitmq"].ecs_container_essential
          port_mappings         = var.services["rabbitmq"].ecs_container_port_mappings
          environment_variables = var.services["rabbitmq"].ecs_environment_variables
          health_check = {
            command     = var.services["rabbitmq"].ecs_container_health_check.command
            interval    = var.services["rabbitmq"].ecs_container_health_check.interval
            timeout     = var.services["rabbitmq"].ecs_container_health_check.timeout
            retries     = var.services["rabbitmq"].ecs_container_health_check.retries
            startPeriod = var.services["rabbitmq"].ecs_container_health_check.startPeriod
          }
          mount_points = [
            {
              source_volume  = "rabbitmq-data"
              container_path = "/var/lib/rabbitmq"
            }
          ]
          depends_on = []
        },
        {
          # Redis - deployed first as dependency
          name                  = "redis"
          image_repository_url  = var.services["redis"].ecs_container_image_repository_url
          image_tag             = var.services["redis"].ecs_container_image_tag
          cpu                   = var.services["redis"].ecs_container_cpu
          memory                = var.services["redis"].ecs_container_memory
          essential             = var.services["redis"].ecs_container_essential
          port_mappings         = var.services["redis"].ecs_container_port_mappings
          environment_variables = var.services["redis"].ecs_environment_variables
          command               = lookup(var.services["redis"], "command", null)
          health_check = {
            command     = var.services["redis"].ecs_container_health_check.command
            interval    = var.services["redis"].ecs_container_health_check.interval
            timeout     = var.services["redis"].ecs_container_health_check.timeout
            retries     = var.services["redis"].ecs_container_health_check.retries
            startPeriod = var.services["redis"].ecs_container_health_check.startPeriod
          }
          mount_points = [
            {
              source_volume  = "redis-data"
              container_path = "/data"
            }
          ]
          depends_on = []
        },
        {
          # User microservice - depends on RabbitMQ and Redis
          name                 = "user-microservice"
          image_repository_url = var.services["user"].ecs_container_image_repository_url
          image_tag            = var.services["user"].ecs_container_image_tag
          cpu                  = var.services["user"].ecs_container_cpu
          memory               = var.services["user"].ecs_container_memory
          essential            = var.services["user"].ecs_container_essential
          port_mappings        = var.services["user"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["user"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["user"].ecs_container_health_check.command
            interval    = var.services["user"].ecs_container_health_check.interval
            timeout     = var.services["user"].ecs_container_health_check.timeout
            retries     = var.services["user"].ecs_container_health_check.retries
            startPeriod = var.services["user"].ecs_container_health_check.startPeriod
          }
          depends_on = ["rabbitmq", "redis"]
        }
      ]

      target_groups = []
    }
  }

  depends_on = [module.ec2]
}

# ECS Module - Server-2 (API Gateway + Guest microservice)
# Deploys after server-1 to ensure service discovery endpoints are available
module "ecs_server2" {
  source = "./modules/ecs"

  project_name             = var.project_name
  aws_region               = var.aws_region
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  task_subnet_ids          = [module.vpc.private_subnet_id]
  ecs_cluster_id           = module.ec2.ecs_cluster_arn
  ecs_cluster_name         = module.ec2.ecs_cluster_name
  alb_security_group_id    = module.alb.alb_sg_id
  assign_public_ip         = false
  desired_count            = 1
  service_names            = ["server-2"]
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  service_dependencies     = {}
  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_connect   = var.enable_service_connect
  wait_for_steady_state    = true

  # Pass shared resources (same as server-1)
  shared_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
  shared_task_role_arn      = aws_iam_role.ecs_task_role.arn
  shared_execution_role_arn = aws_iam_role.ecs_execution_role.arn
  shared_task_sg_id         = aws_security_group.ecs_task_sg.id
  # Use existing namespace created above
  service_connect_namespace = var.enable_service_connect ? aws_service_discovery_private_dns_namespace.ecs_namespace[0].arn : null

  service_connect_services = {
    server-2 = [
      {
        # Publish guest-service to namespace
        port_name      = var.services["guest"].ecs_service_connect_port_name
        discovery_name = var.services["guest"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["guest"].ecs_service_connect_dns_name
            port     = var.services["guest"].ecs_container_port_mappings[0].container_port
          }
        ]
      },
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
      },
      {
        # Publish API Gateway to namespace
        port_name      = var.services["apigateway"].ecs_service_connect_port_name
        discovery_name = var.services["apigateway"].ecs_service_connect_discovery_name
        client_aliases = [
          {
            dns_name = var.services["apigateway"].ecs_service_connect_dns_name
            port     = var.services["apigateway"].ecs_container_port_mappings[0].container_port
          }
        ]
      }
      # Note: User, RabbitMQ, Redis auto-discovered via Service Connect namespace
    ]
  }

  service_definitions = {
    server-2 = {
      task_cpu            = var.services["guest"].ecs_container_cpu + var.services["apigateway"].ecs_container_cpu + var.services["n8n"].ecs_container_cpu + 64
      task_memory         = var.services["guest"].ecs_container_memory + var.services["apigateway"].ecs_container_memory + var.services["n8n"].ecs_container_memory + 128
      desired_count       = 1
      assign_public_ip    = false
      enable_auto_scaling = false
      placement_constraints = [
        {
          type       = "memberOf"
          expression = "attribute:service_group == server-2"
        }
      ]

      volumes = [
        {
          name      = "n8n-data"
          host_path = "/var/lib/${var.project_name}/n8n"
        }
      ]

      containers = [
        {
          # Guest microservice - deployed first as dependency for API Gateway
          name                 = "guest-microservice"
          image_repository_url = var.services["guest"].ecs_container_image_repository_url
          image_tag            = var.services["guest"].ecs_container_image_tag
          cpu                  = var.services["guest"].ecs_container_cpu
          memory               = var.services["guest"].ecs_container_memory
          essential            = var.services["guest"].ecs_container_essential
          port_mappings        = var.services["guest"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["guest"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["guest"].ecs_container_health_check.command
            interval    = var.services["guest"].ecs_container_health_check.interval
            timeout     = var.services["guest"].ecs_container_health_check.timeout
            retries     = var.services["guest"].ecs_container_health_check.retries
            startPeriod = var.services["guest"].ecs_container_health_check.startPeriod
          }
          depends_on = []
        },
        {
          # n8n automation - required before API Gateway becomes available
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
              env_var
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
          mount_points = [
            {
              source_volume  = "n8n-data"
              container_path = "/home/node/.n8n"
            }
          ]
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
        },
        {
          # API Gateway - depends on Guest microservice and n8n
          name                 = "api-gateway"
          image_repository_url = var.services["apigateway"].ecs_container_image_repository_url
          image_tag            = var.services["apigateway"].ecs_container_image_tag
          cpu                  = var.services["apigateway"].ecs_container_cpu
          memory               = var.services["apigateway"].ecs_container_memory
          essential            = var.services["apigateway"].ecs_container_essential
          port_mappings        = var.services["apigateway"].ecs_container_port_mappings
          environment_variables = [
            for env_var in var.services["apigateway"].ecs_environment_variables :
            env_var
          ]
          health_check = {
            command     = var.services["apigateway"].ecs_container_health_check.command
            interval    = var.services["apigateway"].ecs_container_health_check.interval
            timeout     = var.services["apigateway"].ecs_container_health_check.timeout
            retries     = var.services["apigateway"].ecs_container_health_check.retries
            startPeriod = var.services["apigateway"].ecs_container_health_check.startPeriod
          }
          depends_on = ["guest-microservice", "n8n"]
        }
      ]

      target_groups = [
        {
          # API Gateway to ALB Target Group
          target_group_arn = module.alb.target_group_arns_map["apigateway"]
          container_name   = "api-gateway"
          container_port   = var.services["apigateway"].ecs_container_port_mappings[0].container_port
        },
        {
          # n8n HTTP exposure via ALB
          target_group_arn = module.alb.target_group_arns_map["n8n"]
          container_name   = "n8n-proxy"
          container_port   = 8088
        }
      ]
    }
  }

  depends_on = [module.ecs_server1]
}

# CloudFront Module (Optional - for free HTTPS)
module "cloudfront" {
  count  = var.use_cloudfront_https ? 1 : 0
  source = "./modules/cloudfront"

  project_name = var.project_name
  alb_dns_name = module.alb.alb_dns_name
  alb_id       = module.alb.alb_arn
  enable_caching = var.cloudfront_enable_caching

  # CloudFront settings optimized for API/microservices
  viewer_protocol_policy = "redirect-to-https"  # Redirect HTTP to HTTPS
  price_class            = "PriceClass_100"     # Use only North America and Europe (cheapest)

  # Caching configuration
  min_ttl     = var.cloudfront_enable_caching ? 0 : 0
  default_ttl = var.cloudfront_enable_caching ? 3600 : 0
  max_ttl     = var.cloudfront_enable_caching ? 86400 : 0
  
  # Forward all cookies, headers, and query strings to support API functionality
  forward_cookies      = "all"
  forward_query_string = true
  forward_headers      = var.cloudfront_enable_caching ? ["Host", "Authorization", "CloudFront-*"] : ["*"]

  # HTTP methods for API support
  allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
  cached_methods   = var.cloudfront_enable_caching ? ["GET", "HEAD", "OPTIONS"] : []
  compress         = true

  # CloudFront access logging (for debugging)
  enable_logging          = var.cloudfront_enable_logging
  logging_bucket          = var.cloudfront_logging_bucket
  logging_prefix          = var.cloudfront_logging_prefix
  logging_include_cookies = var.cloudfront_logging_include_cookies

  depends_on = [module.alb]
}
