resource "aws_db_instance" "this" {
  identifier                            = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds"
  db_name                               = "${replace(replace(var.project, "_", ""), "-", "")}${replace(replace(var.environment, "_", ""), "-", "")}"
  username                              = var.db_username
  manage_master_user_password           = true
  engine                                = var.engine
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = 100 # Auto scaling do storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  vpc_security_group_ids                = var.vpc_security_group_ids
  db_subnet_group_name                  = var.db_subnet_group_name
  publicly_accessible                   = var.environment == "dev" ? true : false
  multi_az                              = var.environment == "prod" ? true : false # Multi-AZ apenas em produção
  backup_retention_period               = var.environment == "prod" ? 7 : 1        # Backup otimizado por ambiente
  backup_window                         = "03:00-04:00"
  maintenance_window                    = "sun:04:00-sun:05:00"
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection                   = true
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  apply_immediately                     = false # Em PROD, aplica na janela de manutenção

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# IAM Role para Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
