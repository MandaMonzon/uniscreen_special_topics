# Lambda Functions Outputs
output "lambda_function_arn" {
  description = "ARN of the main Lambda function"
  value       = module.lambda_functions.get_report_receivables_arn
}

# IAM Outputs
output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = module.iam_for_lambda.lambda_role_arn
}
