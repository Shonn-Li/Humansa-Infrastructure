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

# Public Subnets for ALB and NAT Gateways
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

# Private Subnets for EC2 Instances
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.humansa_vpc.id
  cidr_block        = "10.100.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Type = "Private"
  }
}

# Database Subnets
resource "aws_subnet" "database" {
  count             = 2
  vpc_id            = aws_vpc.humansa_vpc.id
  cidr_block        = "10.100.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-${count.index + 1}"
    Type = "Database"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }
  
  depends_on = [aws_internet_gateway.humansa_igw]
}

# NAT Gateways for private subnet internet access
resource "aws_nat_gateway" "humansa_nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }
  
  depends_on = [aws_internet_gateway.humansa_igw]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.humansa_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.humansa_igw.id
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.humansa_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.humansa_nat[count.index].id
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "database" {
  count          = 2
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# DB Subnet Group
resource "aws_db_subnet_group" "humansa_db_subnet_group" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "humansa_cache_subnet_group" {
  name       = "${var.project_name}-${var.environment}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-cache-subnet-group"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}