module "rds" {
  source   = "./modules/rds"
  for_each = local.rds_definitions

  project_name            = var.project_name
  identifier              = "${var.project_name}-${each.value.service}-${each.value.db_name}-db"
  db_name                 = each.value.db_name
  username                = each.value.username
  password                = each.value.password
  engine_version          = each.value.engine_version
  instance_class          = each.value.instance_class
  allocated_storage       = each.value.allocated_storage
  max_allocated_storage   = each.value.max_allocated_storage
  backup_retention_period = each.value.backup_retention_period
  deletion_protection     = each.value.deletion_protection
  publicly_accessible     = each.value.publicly_accessible
  port                    = each.value.port
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_group_ids = local.eks_enabled ? [
    aws_security_group.ecs_task_sg.id,
    module.eks[0].node_security_group_id
    ] : [
    aws_security_group.ecs_task_sg.id
  ]

  tags = merge({
    Environment = "production"
    Service     = each.key
  }, each.value.tags)
}
