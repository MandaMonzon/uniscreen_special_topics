variable "project" {
  description = "Project name (e.g., uniscreen)"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, hom, prod)"
  type        = string
}

variable "region" {
  description = "AWS region (use us-east-2 per requirements)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

# Networking and DB (from shared module)
variable "vpc_id" {
  description = "VPC ID from shared module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security Group ID for Lambdas with RDS access"
  type        = string
}

variable "db_endpoint" {
  description = "RDS endpoint from shared module"
  type        = string
}

variable "db_name" {
  description = "RDS database name from shared module"
  type        = string
}

variable "db_port" {
  description = "RDS database port from shared module"
  type        = number
  default     = 5432
}

variable "rds_secret_id" {
  description = "Secrets Manager secret ID/ARN for RDS master user"
  type        = string
}

variable "rds_identifier" {
  description = "RDS DB instance identifier for CloudWatch metrics/alarms"
  type        = string
  default     = ""
}

# Cognito config
variable "cognito_domain_prefix" {
  description = "Cognito domain prefix for the User Pool domain (must be globally unique); default computed from project-env"
  type        = string
  default     = ""
}

# API Gateway
variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}

# S3 Posters
variable "posters_bucket_name" {
  description = "Optional custom S3 bucket name for posters. If empty, one will be generated."
  type        = string
  default     = ""
}

# External APIs
variable "omdb_api_key_secret_arn" {
  description = "Secrets Manager secret ARN containing OMDb API key (plaintext value in 'OMDB_API_KEY')"
  type        = string
  default     = ""
}
