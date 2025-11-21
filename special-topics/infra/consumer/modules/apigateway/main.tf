# API Gateway
resource "aws_api_gateway_rest_api" "debito_automatico_api" {
  name        = "${var.project}_consumer_api"
  description = "API Gateway for ${var.project} project"
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "cognito_authorizer"
  rest_api_id     = aws_api_gateway_rest_api.debito_automatico_api.id
  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
}

# Debit
module "debit_resource" {
  source                = "./dynamic_apigateway"
  rest_api_id           = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id             = aws_api_gateway_rest_api.debito_automatico_api.root_resource_id
  path_full             = "debit"
  path_part             = "debit"
  http_methods          = []
  lambda_function_names = {}
  authorizer_id         = aws_api_gateway_authorizer.cognito_authorizer.id
  region                = var.region
  account_id            = var.account_id
  enable_cors           = false
  depends_on            = [aws_api_gateway_authorizer.cognito_authorizer]
}

module "report_resource" {
  source                = "./dynamic_apigateway"
  rest_api_id           = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id             = module.debit_resource.resource_id
  path_full             = "debit/report"
  path_part             = "report"
  http_methods          = []
  lambda_function_names = {}
  authorizer_id         = aws_api_gateway_authorizer.cognito_authorizer.id
  region                = var.region
  account_id            = var.account_id
  enable_cors           = false
  depends_on            = [aws_api_gateway_authorizer.cognito_authorizer]
}

module "validate_debit_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.debit_resource.resource_id
  path_full    = "debit/validate"
  path_part    = "validate"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = "${var.project}_consumer_post_validate_layout"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.debit_resource]
}

module "process_file_debit_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.debit_resource.resource_id
  path_full    = "debit/process"
  path_part    = "process"
  http_methods = ["POST", "GET"]
  lambda_function_names = {
    POST = "${var.project}_consumer_post_process_file"
    GET  = "${var.project}_consumer_get_debit_files_list"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.debit_resource]
}

# Config
module "config_resource" {
  source                = "./dynamic_apigateway"
  rest_api_id           = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id             = aws_api_gateway_rest_api.debito_automatico_api.root_resource_id
  path_full             = "config"
  path_part             = "config"
  http_methods          = []
  lambda_function_names = {}
  authorizer_id         = aws_api_gateway_authorizer.cognito_authorizer.id
  region                = var.region
  account_id            = var.account_id
  enable_cors           = false
  depends_on            = [aws_api_gateway_authorizer.cognito_authorizer]
}

#Return
module "return_files_list_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.debit_resource.resource_id
  path_full    = "debit/return"
  path_part    = "return"
  http_methods = ["GET"]
  lambda_function_names = {
    GET = "${var.project}_consumer_get_return_files_list"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.debit_resource]
}

module "report_receivables_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.report_resource.resource_id
  path_full    = "debit/report/receivables"
  path_part    = "receivables"
  http_methods = ["GET"]
  lambda_function_names = {
    GET = "${var.project}_consumer_get_report_receivables"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.debit_resource]
}

/* module "config_direct_debit_settings_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.config_resource.resource_id
  path_full    = "config/consumer_integration"
  path_part    = "consumer_integration"
  http_methods = ["GET"]
  lambda_function_names = {
    GET = "${var.project}_consumer_get_config_direct_debit_settings"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.config_resource]
} */

/* module "config_direct_debit_options_api" {
  source       = "./dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.debito_automatico_api.id
  parent_id    = module.config_resource.resource_id
  path_full    = "config/direct_debit"
  path_part    = "direct_debit"
  http_methods = ["GET"]
  lambda_function_names = {
    GET = "${var.project}_consumer_get_config_dd_options_list"
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer, module.config_resource]
} */