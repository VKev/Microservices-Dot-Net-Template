# EC2 Module
module "ec2" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_id             = module.vpc.public_subnet_ids[0]
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
      user_data_extra     = ""
    }
    server-3 = {
      instance_attributes = { service_group = "server-3" }
      tags                = { ServiceGroup = "server-3" }
      user_data_extra     = ""
    }
  }

  depends_on = [module.alb]
}

