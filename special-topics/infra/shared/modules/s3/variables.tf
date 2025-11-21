variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "portal-debito-automatico"
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, hom, prod)"
  type        = string
}

variable "tags" {
  description = "Tags for the S3 buckets"
  type        = map(string)
  default     = {}
}
