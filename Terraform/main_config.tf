locals {
  service_discovery_domain = "${var.project_name}.${var.service_discovery_domain_suffix}"
  rabbitmq_host            = "rabbitmq"
  redis_host               = "redis"
  guest_service_host       = "guest-service"
  user_service_host        = "user-service"
  n8n_service_connect_host = var.services["n8n"].ecs_service_connect_dns_name
  n8n_service_port         = var.services.n8n.ecs_container_port_mappings[0].container_port

  # Public endpoint - use Cloudflare if enabled, then CloudFront if enabled, otherwise ALB HTTP
  public_endpoint = var.use_cloudflare ? "https://${var.cloudflare_record_name == "@" ? var.domain_name : "${var.cloudflare_record_name}.${var.domain_name}"}" : (var.use_cloudfront_https ? "https://${module.cloudfront[0].cloudfront_domain_name}" : "http://${module.alb.alb_dns_name}")

  # Proxy depth for n8n - CloudFront adds one more hop (CloudFront -> ALB -> Container)
  # Without CloudFront: 1 (ALB -> Container)
  # With CloudFront: 2 (CloudFront -> ALB -> Container)
  n8n_proxy_depth = var.use_cloudfront_https ? 2 : 1

  rds_config_defaults = {
    username                = "avnadmin"
    password                = ""
    engine_version          = "15.4"
    instance_class          = "db.t3.micro"
    allocated_storage       = 20
    max_allocated_storage   = 100
    backup_retention_period = 1
    deletion_protection     = false
    publicly_accessible     = false
    port                    = 5432
    tags                    = {}
  }

  rds_definitions = {
    for service, cfg in var.rds :
    service => merge(
      local.rds_config_defaults,
      {
        service = service
        db_name = coalesce(
          lookup(cfg, "db_name", null),
          try(distinct(coalescelist(try(cfg.db_names, null), [lookup(cfg, "db_name", "defaultdb")]))[0], null),
          "defaultdb"
        )
        db_names = distinct(coalescelist(try(cfg.db_names, null), [lookup(cfg, "db_name", "defaultdb")]))
      },
      {
        for key, value in cfg :
        key => value if key != "db_names"
      }
    )
  }

  rds_lookup = {
    for key, m in module.rds :
    key => merge(local.rds_definitions[key], {
      host     = m.address
      port     = m.port
      username = m.username
      password = m.password
    })
  }

  rds_placeholder_map = length(local.rds_lookup) == 0 ? {} : merge([
    for key, rds in local.rds_lookup : merge(
      {
        # Base keys per service use the primary DB (rds.db_name)
        "TERRAFORM_RDS_HOST_${upper(rds.service)}"       = rds.host
        "TERRAFORM_RDS_PORT_${upper(rds.service)}"       = tostring(rds.port)
        "TERRAFORM_RDS_DB_${upper(rds.service)}"         = rds.db_name
        "TERRAFORM_RDS_USERNAME_${upper(rds.service)}"   = rds.username
        "TERRAFORM_RDS_PASSWORD_${upper(rds.service)}"   = rds.password
        "TERRAFORM_RDS_PROVIDER_${upper(rds.service)}"   = "postgres"
        "TERRAFORM_RDS_SSLMODE_${upper(rds.service)}"    = "Require"
        "TERRAFORM_RDS_CONNECTION_${upper(rds.service)}" = "Host=${rds.host};Port=${rds.port};Database=${rds.db_name};Username=${rds.username};Password=${rds.password};Ssl Mode=Require;"
      },
      merge([
        for db in(length(rds.db_names) > 0 ? rds.db_names : [rds.db_name]) : {
          "TERRAFORM_RDS_HOST_${upper(rds.service)}_${upper(db)}"       = rds.host
          "TERRAFORM_RDS_PORT_${upper(rds.service)}_${upper(db)}"       = tostring(rds.port)
          "TERRAFORM_RDS_DB_${upper(rds.service)}_${upper(db)}"         = db
          "TERRAFORM_RDS_USERNAME_${upper(rds.service)}_${upper(db)}"   = rds.username
          "TERRAFORM_RDS_PASSWORD_${upper(rds.service)}_${upper(db)}"   = rds.password
          "TERRAFORM_RDS_PROVIDER_${upper(rds.service)}_${upper(db)}"   = "postgres"
          "TERRAFORM_RDS_SSLMODE_${upper(rds.service)}_${upper(db)}"    = "Require"
          "TERRAFORM_RDS_CONNECTION_${upper(rds.service)}_${upper(db)}" = "Host=${rds.host};Port=${rds.port};Database=${db};Username=${rds.username};Password=${rds.password};Ssl Mode=Require;"
        }
      ]...)
    )
  ]...)
}

# VPC Module
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  public_subnet_count  = 2
  private_subnet_cidrs = var.private_subnet_cidrs
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

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_task_ecr_ptc" {
  statement {
    sid = "EcrPullThroughCacheAccess"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:BatchImportUpstreamImage",
      "ecr:CreateRepository",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.dockerhub_pull_through_prefix}/*",
    ]
  }

  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_task_ecr_ptc" {
  name   = "${var.project_name}-ecs-ecr-ptc"
  policy = data.aws_iam_policy_document.ecs_task_ecr_ptc.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_ecr_ptc_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_ecr_ptc.arn
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

resource "aws_secretsmanager_secret" "dockerhub" {
  count = var.dockerhub_credentials_secret_arn == null && var.dockerhub_username != "" && var.dockerhub_password != "" ? 1 : 0
  # New name to force recreation with valid JSON credentials
  name = "ecr-pullthroughcache/${var.dockerhub_pull_through_prefix}-${var.project_name}-creds"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "dockerhub" {
  count     = length(aws_secretsmanager_secret.dockerhub) == 0 ? 0 : 1
  secret_id = aws_secretsmanager_secret.dockerhub[0].id

  secret_string = jsonencode({
    username    = var.dockerhub_username
    accessToken = var.dockerhub_password # this should be your Docker Hub access token
  })
}


resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  count = var.dockerhub_credentials_secret_arn != null || (var.dockerhub_username != "" && var.dockerhub_password != "") ? 1 : 0

  ecr_repository_prefix = var.dockerhub_pull_through_prefix
  upstream_registry_url = var.dockerhub_pull_through_registry
  credential_arn        = coalesce(var.dockerhub_credentials_secret_arn, try(aws_secretsmanager_secret.dockerhub[0].arn, null))

  depends_on = [
    aws_secretsmanager_secret_version.dockerhub
  ]
}

# CloudFront Module (Optional - for free HTTPS)
module "cloudfront" {
  count  = var.use_cloudflare ? 0 : (var.use_cloudfront_https ? 1 : 0)
  source = "./modules/cloudfront"

  project_name   = var.project_name
  alb_dns_name   = module.alb.alb_dns_name
  alb_id         = module.alb.alb_arn
  enable_caching = var.cloudfront_enable_caching

  # CloudFront settings optimized for API/microservices
  viewer_protocol_policy = "redirect-to-https" # Redirect HTTP to HTTPS
  price_class            = "PriceClass_100"    # Use only North America and Europe (cheapest)

  # Caching configuration
  min_ttl     = var.cloudfront_enable_caching ? 0 : 0
  default_ttl = var.cloudfront_enable_caching ? 3600 : 0
  max_ttl     = var.cloudfront_enable_caching ? 86400 : 0

  # Forward all cookies, headers, and query strings to support API functionality
  forward_cookies      = "all"
  forward_query_string = true
  forward_headers      = var.cloudfront_enable_caching ? ["Host", "Authorization", "CloudFront-*"] : ["*"]

  # HTTP methods for API support
  allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
  # CloudFront requires cached_methods to be non-empty even when caching is effectively disabled via policies/TTLs
  cached_methods = ["GET", "HEAD", "OPTIONS"]
  compress       = true

  # CloudFront access logging (for debugging)
  enable_logging          = var.cloudfront_enable_logging
  logging_bucket          = var.cloudfront_logging_bucket
  logging_prefix          = var.cloudfront_logging_prefix
  logging_include_cookies = var.cloudfront_logging_include_cookies

  # S3 Origin
  s3_bucket_domain_name = var.static_assets_bucket_domain_name
  s3_path_pattern       = "/s3/*"
  s3_use_oac            = false # Disabled to allow S3 Presigned URLs

  depends_on = [module.alb]
}
