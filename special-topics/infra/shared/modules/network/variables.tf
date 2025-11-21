// Network Configuration
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

// Project Configuration
variable "environment" {
  description = "The environment for the deployment (e.g., dev, hom, prod)"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
