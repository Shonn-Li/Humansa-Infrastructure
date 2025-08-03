# VPC Configuration
resource "aws_vpc" "humansa_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "humansa_igw" {
  vpc_id = aws_vpc.humansa_vpc.id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public Subnets Only (No NAT needed)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.humansa_vpc.id
  cidr_block              = "10.100.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "Public"
  }
}

# Database Subnets (required for RDS subnet group)
resource "aws_subnet" "database" {
  count                   = 2
  vpc_id                  = aws_vpc.humansa_vpc.id
  cidr_block              = "10.100.${count.index + 20}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-${count.index + 1}"
    Type = "Database"
  }
}

# Simple Route Table for all subnets
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.humansa_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.humansa_igw.id
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-main-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "database" {
  count          = 2
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.main.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "humansa_db_subnet_group" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}