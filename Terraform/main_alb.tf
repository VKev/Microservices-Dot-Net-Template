locals {
  # Short, deterministic prefix to satisfy AWS name limits (<=32 chars for ALB/TG names).
  # Max target group name length: prefix + "-tg-" + longest service key (~11 chars) < 32.
  alb_name_prefix = "${substr(replace(var.project_name, "_", "-"), 0, 8)}-${substr(md5(var.project_name), 0, 4)}"
}

# ALB Module
module "alb" {
  source                = "./modules/alb"
  project_name          = var.project_name
  resource_name_prefix  = local.alb_name_prefix
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  # NodePorts exposed by the EKS services (only used when var.use_eks = true)
  # API Gateway NodePort: 32080
  # n8n proxy NodePort:   30578

  # When running on EKS, target groups need to register EC2 nodes (instance targets) on NodePorts.
  # For ECS, keep the original target types passed from service definitions.
  target_groups_definition = [
    for service_name, service_config in var.services :
    {
      name_suffix = service_name
      port        = var.use_eks ? (service_name == "apigateway" ? 32080 : (service_name == "n8n" ? 30578 : service_config.alb_target_group_port)) : service_config.alb_target_group_port
      protocol    = service_config.alb_target_group_protocol
      target_type = var.use_eks ? "instance" : service_config.alb_target_group_type
      health_check = {
        enabled             = service_config.alb_health_check.enabled
        path                = service_config.alb_health_check.path
        port                = var.use_eks ? (service_name == "apigateway" ? "32080" : (service_name == "n8n" ? "30578" : service_config.alb_health_check.port)) : service_config.alb_health_check.port
        protocol            = service_config.alb_health_check.protocol
        matcher             = service_config.alb_health_check.matcher
        interval            = service_config.alb_health_check.interval
        timeout             = service_config.alb_health_check.timeout
        healthy_threshold   = service_config.alb_health_check.healthy_threshold
        unhealthy_threshold = service_config.alb_health_check.unhealthy_threshold
      }
    }
    if service_config.alb_target_group_port != null || (var.use_eks && contains(["n8n", "apigateway"], service_name))
  ]

  # SSL/TLS Certificate Configuration
  certificate_arn       = local.effective_certificate_arn
  enable_https_redirect = var.enable_https_redirect

  default_listener_action = {
    type                = "forward"
    target_group_suffix = "apigateway"
  }

  listener_rules_definition = [
    for service_name, service_config in var.services :
    {
      priority            = service_config.alb_listener_rule_priority
      target_group_suffix = service_name
      conditions          = service_config.alb_listener_rule_conditions
    }
    if service_config.alb_listener_rule_priority != null
  ]
}

resource "aws_autoscaling_attachment" "alb_apigateway_eks" {
  count = var.use_eks ? 1 : 0

  autoscaling_group_name = module.eks[0].managed_node_groups["default"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = module.alb.target_group_arns_map["apigateway"]

  depends_on = [module.eks]
}

resource "aws_autoscaling_attachment" "alb_n8n_eks" {
  count = var.use_eks ? 1 : 0

  autoscaling_group_name = module.eks[0].managed_node_groups["default"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = module.alb.target_group_arns_map["n8n"]

  depends_on = [module.eks]
}

