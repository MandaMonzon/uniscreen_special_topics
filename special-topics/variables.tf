variable "account_id" {
  description = "The AWS account ID"
  type        = string
  default     = "467163148650"
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "portal_debito_automatico"
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, hom, prod)"
  type        = string
  default     = "dev"
}
