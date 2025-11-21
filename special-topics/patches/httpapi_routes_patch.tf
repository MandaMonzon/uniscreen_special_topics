# HTTP API (API Gateway v2) – Patch de rotas protegidas com Cognito Authorizer (JWT)
# Ajuste os identificadores conforme seus recursos existentes (api_id, authorizer e integrations).
# Este patch força:
#  - authorization_type = "JWT"
#  - authorizer_id = <cognito_authorizer_id>
#  - target apontando para a integração correspondente
#  - auto_deploy na stage para aplicar imediatamente
#
# Pré-requisitos esperados (já existentes no seu código):
#  - aws_apigatewayv2_api.uniscreen_http_api
#  - aws_apigatewayv2_authorizer.uniscreen_cognito_authorizer (com identity_source = $request.header.Authorization
#    e identity_validation_expression = "^Bearer [^ ]+")
#  - aws_apigatewayv2_integration.admin_migrate e aws_apigatewayv2_integration.admin_seed
#
# Se os nomes abaixo forem diferentes no seu código, ajuste as referências.

resource "aws_apigatewayv2_route" "admin_migrate" {
  api_id             = aws_apigatewayv2_api.uniscreen_http_api.id
  route_key          = "POST /admin/migrate"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.uniscreen_cognito_authorizer.id
  target             = "integrations/${aws_apigatewayv2_integration.admin_migrate.id}"
}

resource "aws_apigatewayv2_route" "admin_seed" {
  api_id             = aws_apigatewayv2_api.uniscreen_http_api.id
  route_key          = "POST /admin/seed"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.uniscreen_cognito_authorizer.id
  target             = "integrations/${aws_apigatewayv2_integration.admin_seed.id}"
}

# Garanta que a stage esteja com auto_deploy para refletir a mudança de rotas sem precisar recriar deployment
resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.uniscreen_http_api.id
  name        = var.stage_name
  auto_deploy = true

  # Reforce dependência das rotas para assegurar atualização
  depends_on = [
    aws_apigatewayv2_route.admin_migrate,
    aws_apigatewayv2_route.admin_seed
  ]
}
