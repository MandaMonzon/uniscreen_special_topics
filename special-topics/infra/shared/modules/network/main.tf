// Data sources for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

// VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-vpc"
    Environment = var.environment
    Project     = var.project
  }
}

// Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-igw"
    Environment = var.environment
    Project     = var.project
  }
}

// Private Subnets for RDS and Lambdas
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project
    Type        = "private"
  }

  # Allows ordered destruction - subnets can be removed after dependent resources
  lifecycle {
    create_before_destroy = true
  }
}

// Public Subnets
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project
    Type        = "public"
  }
}

// Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-public-rt"
    Environment = var.environment
    Project     = var.project
  }
}

// Route Table for Private Subnets 
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-private-rt-${count.index + 1}"
    Environment = var.environment
    Project     = var.project
  }
}

// Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

// Route Table Associations - Private
resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id

}

// DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-db-subnet-group"
  subnet_ids = var.environment == "dev" ? aws_subnet.public[*].id : aws_subnet.private[*].id

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-db-subnet-group"
    Environment = var.environment
    Project     = var.project
  }
}

// Security Group for RDS Database
resource "aws_security_group" "rds_sg" {
  name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Allow PostgreSQL from Lambda"
  }

  # Allow public access only in DEV environment for developers
  dynamic "ingress" {
    for_each = var.environment == "dev" ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow PostgreSQL from anywhere (DEV only - for developers)"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-rds-sg"
    Environment = var.environment
    Project     = var.project
  }
}

// Security Group for Lambda Functions
resource "aws_security_group" "lambda_sg" {
  name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-lambda-sg"
  description = "Security group for Lambdas"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Allow PostgreSQL to RDS"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for Secrets Manager, AWS APIs, etc"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for AWS APIs (if needed)"
  }

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-lambda-sg"
    Environment = var.environment
    Project     = var.project
  }
}

// VPC Endpoint for DynamoDB (Gateway Endpoint)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = aws_route_table.private[*].id

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-dynamodb-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// VPC Endpoint for S3 (Gateway Endpoint)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = aws_route_table.private[*].id

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-s3-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// VPC Endpoint for Secrets Manager (Interface Endpoint)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-secretsmanager-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// VPC Endpoint for SQS (Interface Endpoint)
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-sqs-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// VPC Endpoint for Step Functions (Interface Endpoint)
resource "aws_vpc_endpoint" "stepfunctions" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.states"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-stepfunctions-endpoint"
    Environment = var.environment
    Project     = var.project
  }
}

// Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name_prefix = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-vpc-endpoint-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${replace(var.project, "_", "-")}-${replace(var.environment, "_", "-")}-vpc-endpoint-sg"
    Environment = var.environment
    Project     = var.project
  }

  lifecycle {
    create_before_destroy = true
  }
}
