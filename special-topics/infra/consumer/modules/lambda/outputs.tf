output "get_report_receivables_arn" {
  description = "ARN of the get_report_receivables Lambda function"
  value       = module.get_report_receivables.lambda_function_arn
}

output "get_report_receivables_function_name" {
  description = "Name of the get_report_receivables Lambda function"
  value       = module.get_report_receivables.lambda_function_name
}

