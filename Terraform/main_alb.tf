# ALB Module
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  # NodePorts exposed by the EKS services (only used when var.use_eks = true)
  # API Gateway NodePort: 32080
  # n8n proxy NodePort:   30578

  # When running on EKS, target groups need to register EC2 nodes (instance targets) on NodePorts.
  # For ECS, keep the original target types passed from service definitions.
  target_groups_definition = [
    {
      # API Gateway Target Group
      name_suffix = "apigateway"
      port        = var.use_eks ? 32080 : var.services["apigateway"].alb_target_group_port
      protocol    = var.services["apigateway"].alb_target_group_protocol
      target_type = var.use_eks ? "instance" : var.services["apigateway"].alb_target_group_type
      health_check = {
        enabled             = true
        path                = "/api/health"
        port                = var.use_eks ? "32080" : var.services["apigateway"].alb_health_check.port
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
      port        = var.use_eks ? 30578 : var.services["n8n"].alb_target_group_port
      protocol    = var.services["n8n"].alb_target_group_protocol
      target_type = var.use_eks ? "instance" : var.services["n8n"].alb_target_group_type
      health_check = {
        enabled             = var.services["n8n"].alb_health_check.enabled
        path                = var.services["n8n"].alb_health_check.path
        port                = var.use_eks ? "30578" : var.services["n8n"].alb_health_check.port
        protocol            = var.services["n8n"].alb_health_check.protocol
        matcher             = var.services["n8n"].alb_health_check.matcher
        interval            = var.services["n8n"].alb_health_check.interval
        timeout             = var.services["n8n"].alb_health_check.timeout
        healthy_threshold   = var.services["n8n"].alb_health_check.healthy_threshold
        unhealthy_threshold = var.services["n8n"].alb_health_check.unhealthy_threshold
      }
    }
  ]

  # SSL/TLS Certificate Configuration
  certificate_arn       = var.certificate_arn
  enable_https_redirect = var.enable_https_redirect

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

locals {
  eks_default_asg_name = var.use_eks ? try(module.eks[0].managed_node_groups["default"].node_group_autoscaling_group_names[0], null) : null
}

resource "aws_autoscaling_attachment" "alb_apigateway_eks" {
  count = var.use_eks && local.eks_default_asg_name != null ? 1 : 0

  autoscaling_group_name = local.eks_default_asg_name
  lb_target_group_arn    = module.alb.target_group_arns_map["apigateway"]
}

resource "aws_autoscaling_attachment" "alb_n8n_eks" {
  count = var.use_eks && local.eks_default_asg_name != null ? 1 : 0

  autoscaling_group_name = local.eks_default_asg_name
  lb_target_group_arn    = module.alb.target_group_arns_map["n8n"]
}

