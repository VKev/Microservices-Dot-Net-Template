output "endpoint" {
  description = "Connection endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the DB instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = var.db_name
}

output "username" {
  description = "Master username."
  value       = var.username
}

output "password" {
  description = "Master password."
  value       = local.db_password
  sensitive   = true
}

output "security_group_id" {
  description = "Security group protecting the DB."
  value       = aws_security_group.db.id
}
