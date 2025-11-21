output "api_invoke_url" {
  description = "Base invoke URL for the UniScreen API"
  value       = module.uniscreen.api_invoke_url
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = module.uniscreen.cognito_user_pool_arn
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.uniscreen.cognito_user_pool_client_id
}

output "posters_bucket_name" {
  description = "S3 bucket name for posters"
  value       = module.uniscreen.posters_bucket_name
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.shared.db_endpoint
}
