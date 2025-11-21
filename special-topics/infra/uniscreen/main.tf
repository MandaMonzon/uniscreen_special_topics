// Locals
locals {
  domain_prefix       = var.cognito_domain_prefix != "" ? var.cognito_domain_prefix : "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-auth"
  posters_bucket_name = var.posters_bucket_name != "" ? var.posters_bucket_name : "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-posters"
}

/////////////////////
// S3: Posters bucket
resource "aws_s3_bucket" "posters" {
  bucket = local.posters_bucket_name

  tags = {
    Project     = var.project
    Environment = var.environment
    Purpose     = "Movie posters storage"
    Module      = "uniscreen"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "posters_sse" {
  bucket = aws_s3_bucket.posters.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "posters_cors" {
  bucket = aws_s3_bucket.posters.id

  cors_rule {
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Allow public bucket policy for posters bucket (needed for public-read object access)
resource "aws_s3_bucket_public_access_block" "posters_pab" {
  bucket = aws_s3_bucket.posters.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read for objects (to return public poster links)
resource "aws_s3_bucket_policy" "posters_public_read" {
  bucket = aws_s3_bucket.posters.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = "arn:aws:s3:::${aws_s3_bucket.posters.bucket}/*"
      }
    ]
  })
}

/////////////////////
// IAM: Lambda role for UniScreen
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "uniscreen_lambda_role" {
  name               = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-uniscreen-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project     = var.project
    Environment = var.environment
    Module      = "uniscreen"
  }
}

resource "aws_iam_role_policy_attachment" "uniscreen_lambda_basic" {
  role       = aws_iam_role.uniscreen_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "uniscreen_lambda_vpc" {
  role       = aws_iam_role.uniscreen_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Inline policy for Cognito, S3 posters and Secrets Manager (OMDb key)
resource "aws_iam_role_policy" "uniscreen_lambda_inline" {
  name = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-uniscreen-inline"
  role = aws_iam_role.uniscreen_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CognitoIdpAccess",
        Effect = "Allow",
        Action = [
          "cognito-idp:SignUp",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:InitiateAuth",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminRespondToAuthChallenge",
          "cognito-idp:RespondToAuthChallenge"
        ],
        Resource = "*"
      },
      {
        Sid    = "S3PostersAccess",
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.posters.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.posters.bucket}/*"
        ]
      },
      {
        Sid    = "SecretsManagerRead",
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = var.omdb_api_key_secret_arn != "" ? var.omdb_api_key_secret_arn : "*"
      },
      {
        Sid    = "RdsSecretsManagerRead",
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = var.rds_secret_id != "" ? var.rds_secret_id : "*"
      }
    ]
  })
}

/////////////////////
// Cognito: User Pool, Client, Domain
resource "aws_cognito_user_pool" "uniscreen" {
  name = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Keep defaults for schema; simple email/username
  username_attributes = ["email"]

  tags = {
    Project     = var.project
    Environment = var.environment
    Module      = "uniscreen"
  }
}

resource "aws_cognito_user_pool_client" "uniscreen_client" {
  name         = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-app-client"
  user_pool_id = aws_cognito_user_pool.uniscreen.id

  generate_secret              = false
  explicit_auth_flows          = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_ADMIN_USER_PASSWORD_AUTH"]
  supported_identity_providers = ["COGNITO"]

  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 60
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "uniscreen_domain" {
  domain       = local.domain_prefix
  user_pool_id = aws_cognito_user_pool.uniscreen.id
}

/////////////////////
// API Gateway: REST API + Authorizer
resource "aws_api_gateway_rest_api" "uniscreen_api" {
  name        = "${var.project}_api"
  description = "UniScreen API Gateway"
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                           = "uniscreen_cognito_authorizer"
  rest_api_id                    = aws_api_gateway_rest_api.uniscreen_api.id
  identity_source                = "method.request.header.Authorization"
  identity_validation_expression = "^Bearer [^ ]+"
  type                           = "COGNITO_USER_POOLS"
  provider_arns                  = [aws_cognito_user_pool.uniscreen.arn]
}

/////////////////////
// Lambda functions (Auth, Movies, Favorites)
locals {
  vpc_config = var.lambda_security_group_id != null && length(var.private_subnet_ids) > 0 ? {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  } : null
}

# Auth: signup
module "signup_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/auth"
  handler              = "signup.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-signup"
  runtime              = "python3.11"
  timeout              = 10

  vpc_config = null

  environment_variables = {
    USER_POOL_ID        = aws_cognito_user_pool.uniscreen.id
    USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.uniscreen_client.id
    REGION              = var.region
  }
}

# Auth: login
module "login_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/auth"
  handler              = "login.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-login"
  runtime              = "python3.11"
  timeout              = 10

  vpc_config = null

  environment_variables = {
    USER_POOL_ID        = aws_cognito_user_pool.uniscreen.id
    USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.uniscreen_client.id
    REGION              = var.region
  }
}

# Movies: GET /movies
module "movies_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/movies"
  handler              = "get_movies.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-get-movies"
  runtime              = "python3.11"
  layers               = [aws_lambda_layer_version.pg8000.arn]
  timeout              = 20

  vpc_config = local.vpc_config

  environment_variables = {
    PROJECT_NAME    = var.project
    ENVIRONMENT     = var.environment
    DB_ENDPOINT     = var.db_endpoint
    DB_NAME         = var.db_name
    DB_PORT         = tostring(var.db_port)
    RDS_SECRET_ID   = var.rds_secret_id
    REGION          = var.region
    POSTERS_BUCKET  = aws_s3_bucket.posters.bucket
    OMDB_SECRET_ARN = var.omdb_api_key_secret_arn
  }
}

# Favorites: GET/POST /favorites
module "favorites_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/favorites"
  handler              = "favorites.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-favorites"
  runtime              = "python3.11"
  layers               = [aws_lambda_layer_version.pg8000.arn]
  timeout              = 15

  vpc_config = local.vpc_config

  environment_variables = {
    PROJECT_NAME  = var.project
    ENVIRONMENT   = var.environment
    DB_ENDPOINT   = var.db_endpoint
    DB_NAME       = var.db_name
    DB_PORT       = tostring(var.db_port)
    RDS_SECRET_ID = var.rds_secret_id
    REGION        = var.region
  }
}

# Admin: migrate (POST)
module "admin_migrate_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/admin"
  handler              = "admin_migrate.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-admin-migrate"
  runtime              = "python3.12"
  layers               = [aws_lambda_layer_version.pg8000.arn]
  timeout              = 30

  vpc_config = local.vpc_config

  environment_variables = {
    REGION        = var.region
    DB_ENDPOINT   = var.db_endpoint
    DB_NAME       = var.db_name
    DB_PORT       = tostring(var.db_port)
    RDS_SECRET_ID = var.rds_secret_id
  }
}

# Admin: seed (POST)
module "admin_seed_lambda" {
  source               = "../consumer/modules/lambda/dynamic_lambda"
  lambda_role_arn      = aws_iam_role.uniscreen_lambda_role.arn
  source_dir           = "${path.root}/src/uniscreen/lambdas/admin"
  handler              = "admin_seed.lambda_handler"
  lambda_function_name = "${var.project}-${var.environment}-admin-seed"
  runtime              = "python3.12"
  layers               = [aws_lambda_layer_version.pg8000.arn]
  timeout              = 30

  vpc_config = local.vpc_config

  environment_variables = {
    REGION        = var.region
    DB_ENDPOINT   = var.db_endpoint
    DB_NAME       = var.db_name
    DB_PORT       = tostring(var.db_port)
    RDS_SECRET_ID = var.rds_secret_id
  }
}

/////////////////////
// API Gateway: Routes

# Admin parent resource (/admin) - no methods, used as parent for child routes
module "admin_resource" {
  source                = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id           = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id             = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full             = "admin"
  path_part             = "admin"
  http_methods          = []
  lambda_function_names = {}
  authorizer_id         = aws_api_gateway_authorizer.cognito_authorizer.id
  region                = var.region
  account_id            = var.account_id
  enable_cors           = false
  depends_on            = [aws_api_gateway_authorizer.cognito_authorizer]
}

# Public: /signup
module "signup_public_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway_public"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "signup"
  path_part    = "signup"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.signup_lambda.lambda_function_name
  }
  region      = var.region
  account_id  = var.account_id
  enable_cors = true
}

# Public: /login
module "login_public_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway_public"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "login"
  path_part    = "login"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.login_lambda.lambda_function_name
  }
  region      = var.region
  account_id  = var.account_id
  enable_cors = true
}

# Public parent resource (/public) - no methods, used as parent for child routes
module "public_resource" {
  source                = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id           = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id             = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full             = "public"
  path_part             = "public"
  http_methods          = []
  lambda_function_names = {}
  authorizer_id         = aws_api_gateway_authorizer.cognito_authorizer.id
  region                = var.region
  account_id            = var.account_id
  enable_cors           = false
  depends_on            = [aws_api_gateway_authorizer.cognito_authorizer]
}

# Public: /public/migrate
module "admin_migrate_public_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway_public"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = module.public_resource.resource_id
  path_full    = "public/migrate"
  path_part    = "migrate"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.admin_migrate_lambda.lambda_function_name
  }
  region      = var.region
  account_id  = var.account_id
  enable_cors = true
}

# Public: /public/seed
module "admin_seed_public_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway_public"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = module.public_resource.resource_id
  path_full    = "public/seed"
  path_part    = "seed"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.admin_seed_lambda.lambda_function_name
  }
  region      = var.region
  account_id  = var.account_id
  enable_cors = true
}

# Protected: /movies (GET)
module "movies_protected_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "movies"
  path_part    = "movies"
  http_methods = ["GET", "POST"]
  lambda_function_names = {
    GET  = module.movies_lambda.lambda_function_name
    POST = module.movies_lambda.lambda_function_name
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer]
}

# Protected: /favorites (GET/POST)
module "favorites_protected_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "favorites"
  path_part    = "favorites"
  http_methods = ["GET", "POST"]
  lambda_function_names = {
    GET  = module.favorites_lambda.lambda_function_name
    POST = module.favorites_lambda.lambda_function_name
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer]
}

# Admin: routes (protected)
module "admin_migrate_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "admin/migrate"
  path_part    = "migrate"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.admin_migrate_lambda.lambda_function_name
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer]
}

module "admin_seed_api" {
  source       = "../consumer/modules/apigateway/dynamic_apigateway"
  rest_api_id  = aws_api_gateway_rest_api.uniscreen_api.id
  parent_id    = aws_api_gateway_rest_api.uniscreen_api.root_resource_id
  path_full    = "admin/seed"
  path_part    = "seed"
  http_methods = ["POST"]
  lambda_function_names = {
    POST = module.admin_seed_lambda.lambda_function_name
  }
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  region        = var.region
  account_id    = var.account_id
  enable_cors   = true
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer]
}

# Deploy and stage
resource "aws_api_gateway_deployment" "uniscreen_deployment" {
  rest_api_id = aws_api_gateway_rest_api.uniscreen_api.id
  description = "Deployment for UniScreen API"

  depends_on = [
    module.signup_public_api,
    module.login_public_api,
    module.admin_migrate_public_api,
    module.admin_seed_public_api,
    module.movies_protected_api,
    module.favorites_protected_api,
    module.admin_migrate_api,
    module.admin_seed_api
  ]
}

resource "aws_api_gateway_stage" "uniscreen_stage" {
  rest_api_id   = aws_api_gateway_rest_api.uniscreen_api.id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.uniscreen_deployment.id
}
