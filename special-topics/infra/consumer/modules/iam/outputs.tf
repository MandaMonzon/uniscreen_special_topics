output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "queue_poller_lambda_role_arn" {
  description = "ARN da role IAM para Lambda Poller"
  value       = aws_iam_role.queue_poller_lambda_role.arn
}

output "queue_worker_lambda_role_arn" {
  description = "ARN da role IAM para Lambdas Workers"
  value       = aws_iam_role.queue_worker_lambda_role.arn
}

output "step_function_role_arn" {
  description = "ARN da role IAM para Step Functions"
  value       = aws_iam_role.step_function_role.arn
}

output "eventbridge_stepfunction_role_arn" {
  description = "ARN da role IAM para EventBridge executar Step Functions"
  value       = aws_iam_role.eventbridge_stepfunction_role.arn
}
