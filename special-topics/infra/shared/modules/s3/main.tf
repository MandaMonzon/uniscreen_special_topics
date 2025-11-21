// Bucket for direct debit settings files
resource "aws_s3_bucket" "direct_debit_settings_files" {
  bucket = "${var.bucket_prefix}-direct-debit-settings-files-${var.environment}"
  tags = merge(var.tags, {
    Purpose = "Direct debit settings files"
    Bank    = "All"
    Module  = "bank"
  })
}

// Versioning configuration for direct debit settings bucket
resource "aws_s3_bucket_versioning" "direct_debit_settings_versioning" {
  bucket = aws_s3_bucket.direct_debit_settings_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

// Encryption configuration for direct debit settings bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "direct_debit_settings_encryption" {
  bucket = aws_s3_bucket.direct_debit_settings_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// Block public access for direct debit settings bucket
resource "aws_s3_bucket_public_access_block" "direct_debit_settings_pab" {
  bucket = aws_s3_bucket.direct_debit_settings_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Bucket for ready/validated files for sending (1 day lifecycle)
resource "aws_s3_bucket" "direct_debit_ready_files" {
  bucket = "${var.bucket_prefix}-direct-debit-ready-files-${var.environment}"
  tags = merge(var.tags, {
    Purpose   = "Files ready for sending to banking process the payments"
    Lifecycle = "1d"
    Module    = "consumer"
  })
}

// Bucket for files after successful sending (30 days lifecycle)
resource "aws_s3_bucket" "direct_debit_sent_files" {
  bucket = "${var.bucket_prefix}-direct-debit-sent-files-${var.environment}"
  tags = merge(var.tags, {
    Purpose   = "Files successfully sent to banking process the payments"
    Lifecycle = "30d"
    Module    = "consumer"
  })
}

// Bucket for bank return files (30 days lifecycle)
resource "aws_s3_bucket" "direct_debit_return_files" {
  bucket = "${var.bucket_prefix}-direct-debit-return-files-${var.environment}"
  tags = merge(var.tags, {
    Purpose   = "Return files from banking process the payments"
    Lifecycle = "30d"
    Module    = "consumer"
  })
}

// VERSIONING CONFIGURATIONS
// Versioning configuration for ready files bucket
resource "aws_s3_bucket_versioning" "direct_debit_ready_files_versioning" {
  bucket = aws_s3_bucket.direct_debit_ready_files.id
  versioning_configuration {
    status = "Suspended"
  }
}

// Versioning configuration for sent files bucket
resource "aws_s3_bucket_versioning" "direct_debit_sent_files_versioning" {
  bucket = aws_s3_bucket.direct_debit_sent_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

// Versioning configuration for return files bucket
resource "aws_s3_bucket_versioning" "direct_debit_return_files_versioning" {
  bucket = aws_s3_bucket.direct_debit_return_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

// LIFECYCLE CONFIGURATIONS
// Lifecycle configuration for ready files (1 day)
resource "aws_s3_bucket_lifecycle_configuration" "direct_debit_ready_files_lifecycle" {
  bucket = aws_s3_bucket.direct_debit_ready_files.id

  rule {
    id     = "ready_files_lifecycle_rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

// Lifecycle configuration for sent files (30 days)
resource "aws_s3_bucket_lifecycle_configuration" "direct_debit_sent_files_lifecycle" {
  bucket = aws_s3_bucket.direct_debit_sent_files.id

  rule {
    id     = "sent_files_lifecycle_rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

// Lifecycle configuration for return files (30 days)
resource "aws_s3_bucket_lifecycle_configuration" "direct_debit_return_files_lifecycle" {
  bucket = aws_s3_bucket.direct_debit_return_files.id

  rule {
    id     = "return_files_lifecycle_rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

// ENCRYPTION CONFIGURATIONS
// Encryption configuration for ready files bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "direct_debit_ready_files_encryption" {
  bucket = aws_s3_bucket.direct_debit_ready_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// Encryption configuration for sent files bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "direct_debit_sent_files_encryption" {
  bucket = aws_s3_bucket.direct_debit_sent_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// Encryption configuration for return files bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "direct_debit_return_files_encryption" {
  bucket = aws_s3_bucket.direct_debit_return_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// PUBLIC ACCESS BLOCK
// Block public access for ready files bucket
resource "aws_s3_bucket_public_access_block" "direct_debit_ready_files_pab" {
  bucket = aws_s3_bucket.direct_debit_ready_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Block public access for sent files bucket
resource "aws_s3_bucket_public_access_block" "direct_debit_sent_files_pab" {
  bucket = aws_s3_bucket.direct_debit_sent_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Block public access for return files bucket
resource "aws_s3_bucket_public_access_block" "direct_debit_return_files_pab" {
  bucket = aws_s3_bucket.direct_debit_return_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
