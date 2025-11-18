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

