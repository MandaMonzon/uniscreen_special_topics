output "direct_debit_settings_files_bucket_name" {
  description = "Name of the bucket for direct debit settings files"
  value       = aws_s3_bucket.direct_debit_settings_files.bucket
}

output "direct_debit_settings_files_bucket_arn" {
  description = "ARN of the bucket for direct debit settings files"
  value       = aws_s3_bucket.direct_debit_settings_files.arn
}

output "direct_debit_ready_files_bucket_name" {
  description = "Name of the bucket for files ready to send to direct debit process"
  value       = aws_s3_bucket.direct_debit_ready_files.bucket
}

output "direct_debit_ready_files_bucket_arn" {
  description = "ARN of the bucket for files ready to send to direct debit process"
  value       = aws_s3_bucket.direct_debit_ready_files.arn
}

output "direct_debit_sent_files_bucket_name" {
  description = "Name of the bucket for direct debit sent files"
  value       = aws_s3_bucket.direct_debit_sent_files.bucket
}

output "direct_debit_sent_files_bucket_arn" {
  description = "ARN of the bucket for direct debit sent files"
  value       = aws_s3_bucket.direct_debit_sent_files.arn
}

output "direct_debit_return_files_bucket_name" {
  description = "Name of the bucket for direct debit return files"
  value       = aws_s3_bucket.direct_debit_return_files.bucket
}

output "direct_debit_return_files_bucket_arn" {
  description = "ARN of the bucket for direct debit return files"
  value       = aws_s3_bucket.direct_debit_return_files.arn
}