# VPC Module
module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  public_subnet_count = 2

  private_subnet_cidr = var.private_subnet_cidr
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  target_groups_definition = [
    {
      name_suffix = "guest"
      port        = 5001
      protocol    = "HTTP"
      target_type = "instance"

      health_check = {
        enabled             = true
        path                = "/api/guest/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    },
    {
      name_suffix = "user"
      port        = 5002
      protocol    = "HTTP"
      target_type = "instance"

      health_check = {
        enabled             = true
        path                = "/api/user/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  ]
  default_listener_action = {
    type = "fixed-response"
    fixed_response = {
      content_type = "text/plain"
      message_body = "Error: Path not found."
      status_code  = "404"
    }
  }

  listener_rules_definition = [
    {
      priority            = 10
      target_group_suffix = "guest"
      conditions = [
        {
          path_pattern = {
            values = ["/api/guest/*"]
          }
        }
      ]
    },
    {
      priority            = 11
      target_group_suffix = "user"
      conditions = [
        {
          path_pattern = {
            values = ["/api/user/*"]
          }
        }
      ]
    }
  ]
}

module "ec2" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_id             = module.vpc.public_subnet_ids[0]
  instance_type         = var.instance_type
  associate_public_ip   = var.associate_public_ip
  alb_security_group_id = module.alb.alb_sg_id

  depends_on = [module.alb]
}


module "ecs" {
  source = "./modules/ecs"

  project_name     = var.project_name
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id
  ecs_cluster_id   = module.ec2.ecs_cluster_arn
  ecs_cluster_name = module.ec2.ecs_cluster_name
  desired_count    = 1

  task_cpu    = 825
  task_memory = 825

  containers = [
    {
      name                 = "guest-microservice"
      image_repository_url = "something.dkr.ecr.us-east-1.amazonaws.com/goodmeal-ecr"
      image_tag            = "Guest.Microservice-latest"
      cpu                  = 400
      memory               = 400
      essential            = true
      port_mappings = [
        {
          container_port = 5001
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      environment_variables = [
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = "Production"
        },
        {
          name  = "DATABASE_HOST"
          value = "your database host"
        },
        {
          name  = "DATABASE_PORT"
          value = "16026"
        },
        {
          name  = "DATABASE_NAME"
          value = "defaultdb"
        },
        {
          name  = "DATABASE_USERNAME"
          value = "avnadmin"
        },
        {
          name  = "DATABASE_PASSWORD"
          value = "your password"
        },
        {
          name  = "ASPNETCORE_URLS"
          value = "http://0.0.0.0:5001"
        },
        {
          name  = "RABBITMQ_URL"
          value = "amqps://cloud of rabbit mq.lmq.cloudamqp.com/"
        },
        {
          name  = "RABBITMQ_HOST"
          value = "rabbit-mq"
        },
        {
          name  = "RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "RABBITMQ_USERNAME"
          value = "rabbitmq"
        },
        {
          name  = "RABBITMQ_PASSWORD"
          value = "your password if used local"
        },
        {
          name  = "REDIS_HOST"
          value = "redis-cloud.com"
        },
        {
          name  = "REDIS_PASSWORD"
          value = "redis password"
        },
        {
          name  = "REDIS_PORT"
          value = "11762"
        }
      ]
      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5001/api/guest/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
      enable_service_discovery = var.enable_service_discovery
      service_discovery_port = 5001
    },
    {
      name                 = "user-microservice"
      image_repository_url = "something.dkr.ecr.us-east-1.amazonaws.com/goodmeal-ecr"
      image_tag            = "User.Microservice-latest"
      cpu                  = 400
      memory               = 400
      essential            = true
      port_mappings = [
        {
          container_port = 5002
          host_port      = 0
          protocol       = "tcp"
        }
      ]
      environment_variables = [
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = "Production"
        },
        {
          name  = "DATABASE_HOST"
          value = "your second db host"
        },
        {
          name  = "DATABASE_PORT"
          value = "19217"
        },
        {
          name  = "DATABASE_NAME"
          value = "defaultdb"
        },
        {
          name  = "DATABASE_USERNAME"
          value = "avnadmin"
        },
        {
          name  = "DATABASE_PASSWORD"
          value = "your password"
        },
        {
          name  = "ASPNETCORE_URLS"
          value = "http://0.0.0.0:5002"
        },
        {
          name  = "RABBITMQ_URL"
          value = "amqps://same cloud of rabbit mq.cloudamqp.com/xcjmxyuo"
        },
        {
          name  = "RABBITMQ_HOST"
          value = "rabbit-mq"
        },
        {
          name  = "RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "RABBITMQ_USERNAME"
          value = "rabbitmq"
        },
        {
          name  = "RABBITMQ_PASSWORD"
          value = "your password"
        },
        {
          name  = "REDIS_HOST"
          value = "redis-cloud.com"
        },
        {
          name  = "REDIS_PASSWORD"
          value = "your password"
        },
        {
          name  = "REDIS_PORT"
          value = "11762"
        }
      ]
      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5002/api/user/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
      enable_service_discovery = var.enable_service_discovery
      service_discovery_port   = 5002
    }
  ]

  target_groups = [
    {
      target_group_arn = module.alb.target_group_arns_map["guest"]
      container_name   = "goodmeal-guest-microservice"
      container_port   = 5001
    },
    {
      target_group_arn = module.alb.target_group_arns_map["user"]
      container_name   = "goodmeal-user-microservice"
      container_port   = 5002
    }
  ]

  enable_auto_scaling      = var.enable_auto_scaling
  enable_service_discovery = var.enable_service_discovery

  depends_on = [module.ec2]
}

# module "lambda_edge" {
#   source = "./modules/lambda_edge"
# }

# module "cloudfront" {
#   source                = "./modules/cloudfront"
#   project_name          = var.project_name
#   origin_domain_name    = var.origin_domain_name
#   origin_path           = var.origin_path
#   set_cookie_lambda_arn = module.lambda_edge.lambda_function_qualified_arn
#   bucket_secret_referer = var.bucket_secret_referer
# }
