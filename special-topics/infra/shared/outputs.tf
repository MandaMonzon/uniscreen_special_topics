// Network outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = module.network.lambda_security_group_id
}

// Database outputs
output "db_endpoint" {
  description = "RDS database endpoint"
  value       = length(module.db_classic) > 0 ? module.db_classic[0].rds_endpoint : null
}

output "db_name" {
  description = "RDS database name"
  value       = length(module.db_classic) > 0 ? module.db_classic[0].rds_db_name : null
}

output "db_port" {
  description = "RDS database port"
  value       = length(module.db_classic) > 0 ? module.db_classic[0].rds_port : 5432
}

output "rds_secret_id" {
  description = "ID of the RDS master user secret"
  value       = length(module.db_classic) > 0 ? module.db_classic[0].db_user_secret_arn : null
}

// IAM outputs
output "lambda_rds_role_arn" {
  description = "ARN of the Lambda RDS IAM role"
  value       = module.iam_for_lambda.lambda_rds_role_arn
}

output "lambda_rds_role_name" {
  description = "Name of the Lambda RDS IAM role"
  value       = module.iam_for_lambda.lambda_rds_role_name
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = length(module.db_classic) > 0 ? module.db_classic[0].rds_identifier : null
}
