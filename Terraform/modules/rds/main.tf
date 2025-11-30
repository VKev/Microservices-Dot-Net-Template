locals {
  db_password = var.password != "" ? var.password : random_password.db_password[0].result
}

resource "random_password" "db_password" {
  count            = var.password == "" ? 1 : 0
  length           = 24
  special          = true
  override_special = "!#$%&()*+,-.:;<=>?[]^_{|}~" # exclude '/', '@', '\"', and space
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.identifier}-subnets-"
  subnet_ids  = var.subnet_ids

  tags = merge({
    Name    = "${var.project_name}-${var.identifier}-subnets"
    Project = var.project_name
  }, var.tags)
}

resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-${var.identifier}-db-"
  description = "Access for ${var.identifier} database"
  vpc_id      = var.vpc_id



  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name    = "${var.project_name}-${var.identifier}-db-sg"
    Project = var.project_name
  }, var.tags)
}

resource "aws_security_group_rule" "ingress" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  description              = "DB access from allowed SG"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.db.id
}

resource "aws_db_instance" "this" {
  identifier                   = var.identifier
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  publicly_accessible          = var.publicly_accessible
  deletion_protection          = var.deletion_protection
  backup_retention_period      = var.backup_retention_period
  storage_encrypted            = true
  apply_immediately            = true
  username                     = var.username
  password                     = local.db_password
  db_name                      = var.db_name
  port                         = var.port
  skip_final_snapshot          = true
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  tags = merge({
    Name    = "${var.project_name}-${var.identifier}"
    Project = var.project_name
  }, var.tags)
}
