# EC2 Module
module "ec2" {
  count                 = var.use_eks ? 0 : 1
  source                = "./modules/ec2"
  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  subnet_id             = module.vpc.public_subnet_ids[0]
  instance_type         = var.instance_type
  associate_public_ip   = var.associate_public_ip
  alb_security_group_id = module.alb.alb_sg_id
  container_instance_groups = {
    for group_name, group_config in var.ecs_service_groups :
    group_name => {
      instance_attributes = { service_group = group_name }
      tags                = { ServiceGroup = group_name }
      user_data_extra = join("\n", [
        for vol in group_config.volumes :
        <<-EOT
          mkdir -p ${replace(vol.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)}
          chown 999:999 ${replace(vol.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)} || true
          chmod 0775 ${replace(vol.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)} || chmod 0777 ${replace(vol.host_path, "TERRAFORM_PROJECT_NAME", var.project_name)}
        EOT
      ])
    }
  }

  depends_on = [module.alb]
}
