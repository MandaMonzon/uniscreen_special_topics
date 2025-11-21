// IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-${var.environment}-consumer-lambda"
  assume_role_policy = file("${path.module}/policies/lambda_assume_role_policy.json")
}

// IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project}-${var.environment}-consumer-lambda-s3"
  role = aws_iam_role.lambda_role.id

  policy = file("${path.module}/policies/worker_lambda_s3_policy.json")
}

resource "aws_iam_role_policy" "lambda_sqs_send_policy" {
  name = "${var.project}-${var.environment}-consumer-lambda-sqs"
  role = aws_iam_role.lambda_role.id

  policy = file("${path.module}/policies/lambda_sqs_send_policy.json")
}

// Add RDS and Secrets Manager permissions to the main lambda role
resource "aws_iam_role_policy" "lambda_rds_access_policy" {
  name = "${var.project}-${var.environment}-consumer-lambda-rds"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:*:*:dbuser:*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets_manager_policy" {
  name = "${var.project}-${var.environment}-consumer-lambda-secrets"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:*"
      }
    ]
  })
}

// IAM Role for Queue Poller Lambda
resource "aws_iam_role" "queue_poller_lambda_role" {
  name               = "${var.project}-${var.environment}-consumer-poller"
  assume_role_policy = file("${path.module}/policies/lambda_assume_role_policy.json")

  tags = var.tags
}

// IAM Role for Worker Lambdas
resource "aws_iam_role" "queue_worker_lambda_role" {
  name               = "${var.project}-${var.environment}-consumer-worker"
  assume_role_policy = file("${path.module}/policies/lambda_assume_role_policy.json")

  tags = var.tags
}

// IAM Role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name               = "${var.project}-${var.environment}-consumer-sfn"
  assume_role_policy = file("${path.module}/policies/step_function_assume_role_policy.json")

  tags = var.tags
}

// IAM Role for EventBridge to execute Step Functions
resource "aws_iam_role" "eventbridge_stepfunction_role" {
  name               = "${var.project}-${var.environment}-consumer-eb-sfn"
  assume_role_policy = file("${path.module}/policies/eventbridge_assume_role_policy.json")

  tags = var.tags
}

// Policy Attachments for Queue Poller Lambda
resource "aws_iam_role_policy_attachment" "poller_lambda_basic_execution" {
  role       = aws_iam_role.queue_poller_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "poller_lambda_vpc_access" {
  role       = aws_iam_role.queue_poller_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "poller_lambda_sqs_policy" {
  name = "${var.project}-${var.environment}-consumer-poller-sqs"
  role = aws_iam_role.queue_poller_lambda_role.id

  policy = file("${path.module}/policies/poller_lambda_sqs_policy.json")
}

resource "aws_iam_role_policy" "poller_lambda_step_function_policy" {
  name = "${var.project}-${var.environment}-consumer-poller-sfn"
  role = aws_iam_role.queue_poller_lambda_role.id

  policy = file("${path.module}/policies/poller_lambda_step_function_policy.json")
}

// Policy Attachments for Worker Lambdas
resource "aws_iam_role_policy_attachment" "worker_lambda_basic_execution" {
  role       = aws_iam_role.queue_worker_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "worker_lambda_vpc_access" {
  role       = aws_iam_role.queue_worker_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "worker_lambda_s3_policy" {
  name = "${var.project}-${var.environment}-consumer-worker-s3"
  role = aws_iam_role.queue_worker_lambda_role.id

  policy = file("${path.module}/policies/worker_lambda_s3_policy.json")
}

resource "aws_iam_role_policy" "worker_lambda_sns_policy" {
  name = "${var.project}-${var.environment}-consumer-worker-sns"
  role = aws_iam_role.queue_worker_lambda_role.id

  policy = file("${path.module}/policies/worker_lambda_sns_policy.json")
}

resource "aws_iam_role_policy" "worker_lambda_secrets_manager_policy" {
  name = "${var.project}-${var.environment}-consumer-worker-secrets"
  role = aws_iam_role.queue_worker_lambda_role.id

  policy = file("${path.module}/policies/worker_lambda_secrets_manager_policy.json")
}

// Add RDS permissions to worker lambda role
resource "aws_iam_role_policy" "worker_lambda_rds_policy" {
  name = "${var.project}-${var.environment}-consumer-worker-rds"
  role = aws_iam_role.queue_worker_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:*:*:dbuser:*/*"
        ]
      }
    ]
  })
}

// Policy Attachments for Step Functions
resource "aws_iam_role_policy" "step_function_lambda_policy" {
  name = "${var.project}-${var.environment}-consumer-sfn-lambda"
  role = aws_iam_role.step_function_role.id

  policy = file("${path.module}/policies/step_function_lambda_policy.json")
}

resource "aws_iam_role_policy" "step_function_logs_policy" {
  name = "${var.project}-${var.environment}-consumer-sfn-logs"
  role = aws_iam_role.step_function_role.id

  policy = file("${path.module}/policies/step_function_logs_policy.json")
}

// Policy for EventBridge to execute Step Functions
resource "aws_iam_role_policy" "eventbridge_stepfunction_policy" {
  name = "${var.project}-${var.environment}-consumer-eb-sfn"
  role = aws_iam_role.eventbridge_stepfunction_role.id

  policy = file("${path.module}/policies/eventbridge_stepfunction_policy.json")
}