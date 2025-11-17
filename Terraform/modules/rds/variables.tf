variable "project_name" {
  description = "Project name used for tagging and naming."
  type        = string
}

variable "identifier" {
  description = "Unique RDS instance identifier."
  type        = string
}

variable "db_name" {
  description = "Initial database name to create."
  type        = string
  default     = "defaultdb"
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "Master password (if empty, a random one will be generated)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Instance size."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling."
  type        = number
  default     = 100
}

variable "backup_retention_period" {
  description = "Backup retention in days."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Enable deletion protection."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the instance is publicly accessible."
  type        = bool
  default     = false
}

variable "port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "vpc_id" {
  description = "VPC ID for security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the DB subnet group (needs at least two AZs)."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to access the DB."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
