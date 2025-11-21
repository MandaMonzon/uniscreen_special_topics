// Locals Configuration
locals {
  db_username       = "${var.project}_${var.environment}_admin"
  az_count          = 2 # RDS requires at least 2 AZs
  instance_class    = "db.t4g.micro"
  allocated_storage = var.environment == "prod" ? 40 : 20
}

// Network Module
module "network" {
  source = "./modules/network"

  vpc_cidr    = var.vpc_cidr
  environment = var.environment
  project     = var.project
  az_count    = local.az_count
  region      = var.region
}

// IAM Module
module "iam_for_lambda" {
  source = "./modules/iam"
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

// Module: RDS Classic
module "db_classic" {
  source = "./modules/rds_classic"

  count = 1

  db_username            = local.db_username
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = local.instance_class
  allocated_storage      = local.allocated_storage
  db_subnet_group_name   = module.network.db_subnet_group_name
  vpc_security_group_ids = [module.network.rds_security_group_id]
  project                = var.project
  environment            = var.environment
}
