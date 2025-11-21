terraform {
  backend "s3" {
    bucket = "amandatest-special-topics-cloud-2"
    key    = "back_end_state_file/terraform.tfstate"
    region = "us-east-1"
  }
}

// Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

// Importa o módulo "shared"
module "shared" {
  source      = "./infra/shared"
  project     = var.project
  environment = var.environment
  region      = var.region
}

module "consumer" {
  source      = "./infra/consumer"
  project     = var.project
  environment = var.environment
  region      = var.region
  account_id  = data.aws_caller_identity.current.account_id

  # Network configuration from shared module
  vpc_id                   = module.shared.vpc_id
  private_subnet_ids       = module.shared.private_subnet_ids
  lambda_security_group_id = module.shared.lambda_security_group_id

  # Database configuration from shared module
  db_endpoint   = module.shared.db_endpoint
  db_name       = module.shared.db_name
  db_port       = module.shared.db_port
  rds_secret_id = module.shared.rds_secret_id

  # IAM configuration from shared module
  lambda_rds_role_arn  = module.shared.lambda_rds_role_arn
  lambda_rds_role_name = module.shared.lambda_rds_role_name

  # S3 buckets - placeholder values
  s3_settings_files_bucket_name = "${var.project}-${var.environment}-settings-files"
  s3_ready_files_bucket_name    = "${var.project}-${var.environment}-ready-files"
  s3_sent_files_bucket_name     = "${var.project}-${var.environment}-sent-files"
  s3_return_files_bucket_name   = "${var.project}-${var.environment}-return-files"
}

# UniScreen stack (Cognito-authenticated API, Lambdas, S3 posters)
module "uniscreen" {
  source      = "./infra/uniscreen"
  project     = "uniscreen"
  environment = var.environment
  region      = var.region
  account_id  = data.aws_caller_identity.current.account_id

  # Network configuration from shared module
  vpc_id                   = module.shared.vpc_id
  private_subnet_ids       = module.shared.private_subnet_ids
  lambda_security_group_id = module.shared.lambda_security_group_id

  # Database configuration from shared module
  db_endpoint    = module.shared.db_endpoint
  db_name        = module.shared.db_name
  db_port        = module.shared.db_port
  rds_secret_id  = module.shared.rds_secret_id
  rds_identifier = module.shared.rds_identifier

  # API Gateway
  stage_name = var.environment

  # Optional overrides
  cognito_domain_prefix   = ""
  posters_bucket_name     = ""
  omdb_api_key_secret_arn = "arn:aws:secretsmanager:us-east-2:728942240812:secret:uniscreen/omdb_api_key-DQHXjK"
}
