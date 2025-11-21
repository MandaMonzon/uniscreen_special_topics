output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.uniscreen_api.id
}

output "api_invoke_url" {
  description = "Base invoke URL for the UniScreen API"
  value       = "https://${aws_api_gateway_rest_api.uniscreen_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.uniscreen_stage.stage_name}"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.uniscreen.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.uniscreen.arn
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.uniscreen_client.id
}

output "cognito_domain" {
  description = "Cognito hosted domain prefix"
  value       = aws_cognito_user_pool_domain.uniscreen_domain.domain
}

output "posters_bucket_name" {
  description = "S3 bucket name for posters"
  value       = aws_s3_bucket.posters.bucket
}

# Lambda outputs passthrough
output "signup_lambda_name" {
  description = "Lambda function name for signup"
  value       = module.signup_lambda.lambda_function_name
}

output "signup_lambda_arn" {
  description = "Lambda function ARN for signup"
  value       = module.signup_lambda.lambda_function_arn
}

output "login_lambda_name" {
  description = "Lambda function name for login"
  value       = module.login_lambda.lambda_function_name
}

output "login_lambda_arn" {
  description = "Lambda function ARN for login"
  value       = module.login_lambda.lambda_function_arn
}

output "movies_lambda_name" {
  description = "Lambda function name for GET /movies"
  value       = module.movies_lambda.lambda_function_name
}

output "movies_lambda_arn" {
  description = "Lambda function ARN for GET /movies"
  value       = module.movies_lambda.lambda_function_arn
}

output "favorites_lambda_name" {
  description = "Lambda function name for /favorites"
  value       = module.favorites_lambda.lambda_function_name
}

output "favorites_lambda_arn" {
  description = "Lambda function ARN for /favorites"
  value       = module.favorites_lambda.lambda_function_arn
}
