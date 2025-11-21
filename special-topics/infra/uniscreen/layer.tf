# Local Lambda Layer for pg8000 (built offline into lambda_layer_rds/pg8000_layer.zip)
# Safe mode: new file; does not modify existing resources.
resource "aws_lambda_layer_version" "pg8000" {
  layer_name          = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-pg8000"
  filename            = abspath("${path.module}/../../../lambda_layer_rds/pg8000_layer.zip")
  compatible_runtimes = ["python3.11", "python3.12"]
  description         = "pg8000 client library and dependencies"
}
