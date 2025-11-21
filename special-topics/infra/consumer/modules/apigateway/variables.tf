variable "region" {
  description = "The AWS region"
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "The Client ID of the Cognito User Pool"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}
