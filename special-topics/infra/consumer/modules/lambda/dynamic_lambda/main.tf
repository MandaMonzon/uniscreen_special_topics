resource "aws_lambda_function" "lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role             = var.lambda_role_arn
  handler          = var.handler
  runtime          = var.runtime
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = var.layers != null ? compact(var.layers) : []
  timeout          = var.timeout

  environment {
    variables = var.environment_variables
  }

  # VPC configuration for RDS access
  dynamic "vpc_config" {
    for_each = (var.vpc_config != null &&
      length(try(var.vpc_config.subnet_ids, [])) > 0 &&
    length(try(var.vpc_config.security_group_ids, [])) > 0) ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/zip/${var.lambda_function_name}_function_payload.zip"
}