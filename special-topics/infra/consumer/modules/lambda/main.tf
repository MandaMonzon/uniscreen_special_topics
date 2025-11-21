locals {
  vpc_config = var.lambda_security_group_id != null && length(var.private_subnet_ids) > 0 ? {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  } : null
}

module "get_report_receivables" {
  source               = "./dynamic_lambda"
  lambda_role_arn      = var.lambda_rds_role_arn
  source_dir           = "${path.root}/src/consumer/lambdas/api/report_receivables"
  handler              = "get_report_receivables.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-consumer-get-report-receivables"
  runtime              = "python3.11"
  timeout              = 15

  # Configuração de VPC do módulo shared
  vpc_config = local.vpc_config

  environment_variables = {
    PROJECT_NAME = var.project
    ENVIRONMENT  = var.environment
    # RDS Configuration
    DB_ENDPOINT   = var.db_endpoint
    DB_NAME       = var.db_name
    DB_PORT       = var.db_port
    RDS_SECRET_ID = var.rds_secret_id
    REGION        = var.region
    # S3 Configuration
    S3_READY_BUCKET  = var.s3_ready_files_bucket_name
    S3_SENT_BUCKET   = var.s3_sent_files_bucket_name
    S3_RETURN_BUCKET = var.s3_return_files_bucket_name
  }
}

