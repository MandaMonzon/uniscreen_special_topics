variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, hom, prod)"
  type        = string
}

# S3 bucket variables from shared module - Consumer specific
variable "s3_settings_files_bucket_name" {
  description = "S3 settings files bucket name (from shared)"
  type        = string
}

variable "s3_ready_files_bucket_name" {
  description = "S3 ready files bucket name (from shared)"
  type        = string
}

variable "s3_sent_files_bucket_name" {
  description = "S3 sent files bucket name (from shared)"
  type        = string
}

variable "s3_return_files_bucket_name" {
  description = "S3 return files bucket name (from shared)"
  type        = string
}

# Network configuration variables from shared module
variable "vpc_id" {
  description = "ID of the VPC from shared module"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs from shared module"
  type        = list(string)
  default     = []
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions to access RDS"
  type        = string
  default     = null
}

# Database configuration variables from shared module
variable "db_endpoint" {
  description = "RDS database endpoint from shared module"
  type        = string
}

variable "db_name" {
  description = "RDS database name from shared module"
  type        = string
}

variable "db_port" {
  description = "RDS database port from shared module"
  type        = number
}

variable "rds_secret_id" {
  description = "ID of the master user secret from shared module"
  type        = string
}

# IAM configuration variables from shared module
variable "lambda_rds_role_arn" {
  description = "ARN of the Lambda RDS IAM role from shared module"
  type        = string
}

variable "lambda_rds_role_name" {
  description = "Name of the Lambda RDS IAM role from shared module"
  type        = string
}
