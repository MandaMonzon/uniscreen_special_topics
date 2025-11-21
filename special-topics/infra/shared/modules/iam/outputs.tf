output "lambda_rds_role_arn" {
  description = "ARN of the Lambda RDS IAM role"
  value       = aws_iam_role.lambda_rds_role.arn
}

output "lambda_rds_role_name" {
  description = "Name of the Lambda RDS IAM role"
  value       = aws_iam_role.lambda_rds_role.name
}
