output "rds_endpoint" {
  description = "The RDS instance connection endpoint (hostname only, without port)"
  value       = split(":", aws_db_instance.this.endpoint)[0]
}

output "rds_db_name" {
  description = "The name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "rds_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.this.port
}

output "rds_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.this.identifier
}

output "db_user_secret_arn" {
  description = "The ARN of the master user secret managed by AWS"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "monitoring_role_arn" {
  description = "The ARN of the RDS monitoring role"
  value       = aws_iam_role.rds_monitoring.arn
}
