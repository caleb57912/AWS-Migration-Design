data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

# Remove all rules from the default security group so nothing uses it by accident
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-locked" }
}

# App tier: blocks 0-2
resource "aws_subnet" "app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  tags              = { Name = "${var.name}-app-${var.azs[count.index]}", Tier = "app" }
}

# Integration tier: blocks 3-5
resource "aws_subnet" "integration" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 3)
  tags              = { Name = "${var.name}-integration-${var.azs[count.index]}", Tier = "integration" }
}

# Data tier: blocks 6-8, labeled restricted for ABAC
resource "aws_subnet" "data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 6)
  tags              = { Name = "${var.name}-data-${var.azs[count.index]}", Tier = "data", DataClass = "restricted" }
}

# One route table per tier; only the built-in local route, so no path to the internet
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-app" }
}

resource "aws_route_table" "integration" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-integration" }
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-data" }
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "integration" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.integration[count.index].id
  route_table_id = aws_route_table.integration.id
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# Free private path to S3; traffic never leaves the AWS network
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id, aws_route_table.integration.id, aws_route_table.data.id]
  tags              = { Name = "${var.name}-s3" }
}
