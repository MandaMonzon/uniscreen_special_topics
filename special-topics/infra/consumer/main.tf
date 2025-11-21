# IAM Module
module "iam_for_lambda" {
  source      = "./modules/iam"
  project     = var.project
  environment = var.environment
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Lambda Module
module "lambda_functions" {
  source          = "./modules/lambda"
  project         = var.project
  region          = var.region
  environment     = var.environment
  lambda_role_arn = module.iam_for_lambda.lambda_role_arn

  # S3 configuration
  s3_ready_files_bucket_name  = var.s3_ready_files_bucket_name
  s3_sent_files_bucket_name   = var.s3_sent_files_bucket_name
  s3_return_files_bucket_name = var.s3_return_files_bucket_name

  # Network configuration for VPC
  vpc_id                   = var.vpc_id
  private_subnet_ids       = var.private_subnet_ids
  lambda_security_group_id = var.lambda_security_group_id

  # Database configuration
  db_endpoint   = var.db_endpoint
  db_name       = var.db_name
  db_port       = var.db_port
  rds_secret_id = var.rds_secret_id

  # Alternative IAM role for RDS access
  lambda_rds_role_arn = var.lambda_rds_role_arn
}

