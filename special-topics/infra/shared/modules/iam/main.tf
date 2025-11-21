// IAM Role for Lambda RDS access
resource "aws_iam_role" "lambda_rds_role" {
  name               = "shared_lambda_rds_role"
  assume_role_policy = file("${path.module}/policies/lambda_assume_role_policy.json")

  tags = var.tags
}

// IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

// Custom policy for RDS access
resource "aws_iam_role_policy" "lambda_rds_policy" {
  name = "shared_lambda_rds_policy"
  role = aws_iam_role.lambda_rds_role.id

  policy = file("${path.module}/policies/lambda_rds_policy.json")
}

// Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets_manager_policy" {
  name = "shared_lambda_secrets_manager_policy"
  role = aws_iam_role.lambda_rds_role.id

  policy = file("${path.module}/policies/lambda_secrets_manager_policy.json")
}
