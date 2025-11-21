# CloudWatch Dashboard for UniScreen
resource "aws_cloudwatch_dashboard" "uniscreen_dashboard" {
  dashboard_name = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        "type" : "metric",
        "x" : 0,
        "y" : 0,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "view" : "timeSeries",
          "stacked" : false,
          "region" : var.region,
          "title" : "API Gateway Latency & 5XX",
          "metrics" : [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.uniscreen_api.name, "Stage", var.stage_name, { "stat" : "Average" }],
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.uniscreen_api.name, "Stage", var.stage_name, { "stat" : "Sum" }]
          ]
        }
      },
      {
        "type" : "metric",
        "x" : 0,
        "y" : 6,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "view" : "timeSeries",
          "stacked" : false,
          "region" : var.region,
          "title" : "Lambda Errors",
          "metrics" : [
            ["AWS/Lambda", "Errors", "FunctionName", module.movies_lambda.lambda_function_name, { "stat" : "Sum" }],
            ["AWS/Lambda", "Errors", "FunctionName", module.favorites_lambda.lambda_function_name, { "stat" : "Sum" }]
          ]
        }
      },
      {
        "type" : "metric",
        "x" : 0,
        "y" : 12,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "view" : "timeSeries",
          "stacked" : false,
          "region" : var.region,
          "title" : "RDS CPU & Free Storage",
          "metrics" : [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier, { "stat" : "Average" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_identifier, { "stat" : "Average" }]
          ]
        }
      }
    ]
  })
}

# Basic Alarms

# API Gateway 5XX Errors alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx_alarm" {
  alarm_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-api-5xx"
  alarm_description   = "UniScreen API Gateway 5XX errors alarm"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.uniscreen_api.name
    Stage   = var.stage_name
  }

  alarm_actions = []
  ok_actions    = []
}

# Lambda Errors alarms
resource "aws_cloudwatch_metric_alarm" "movies_lambda_errors" {
  alarm_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-movies-errors"
  alarm_description   = "Errors on movies Lambda"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.movies_lambda.lambda_function_name
  }

  alarm_actions = []
  ok_actions    = []
}

resource "aws_cloudwatch_metric_alarm" "favorites_lambda_errors" {
  alarm_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-favorites-errors"
  alarm_description   = "Errors on favorites Lambda"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.favorites_lambda.lambda_function_name
  }

  alarm_actions = []
  ok_actions    = []
}

# RDS CPU Utilization alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_alarm" {
  alarm_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds-cpu"
  alarm_description   = "RDS CPU utilization high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = []
  ok_actions    = []
}

# RDS Free Storage Space alarm (below 10GB)
resource "aws_cloudwatch_metric_alarm" "rds_storage_alarm" {
  alarm_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds-storage"
  alarm_description   = "RDS free storage space low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10737418240 # 10GB in bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  unit                = "Bytes"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = []
  ok_actions    = []
}
