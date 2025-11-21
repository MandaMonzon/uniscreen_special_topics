variable "lambda_role_arn" {
  description = "The ARN of the IAM role to be assumed by the Lambda function"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

variable "s3_ready_files_bucket_name" {
  description = "S3 bucket name for ready files"
  type        = string
}

variable "s3_sent_files_bucket_name" {
  description = "S3 bucket name for sent files"
  type        = string
}

variable "s3_return_files_bucket_name" {
  description = "S3 bucket name for return files"
  type        = string
}

variable "step_function_download_arn" {
  description = "Step Function Download ARN"
  type        = string
  default     = null
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, hom, prod)"
  type        = string
}

# Network variables for VPC
variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda functions"
  type        = list(string)
  default     = []
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
  default     = null
}

# Database variables
variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
  default     = null
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = null
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "rds_secret_id" {
  description = "ID of the master user secret from shared module"
  type        = string
}

# Alternative IAM role for RDS access
variable "lambda_rds_role_arn" {
  description = "Lambda RDS role ARN from shared module"
  type        = string
  default     = null
}
