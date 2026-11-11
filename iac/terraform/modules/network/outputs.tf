output "vpc_id" {
  value = aws_vpc.this.id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "integration_subnet_ids" {
  value = aws_subnet.integration[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "app_subnet_cidrs" {
  value = aws_subnet.app[*].cidr_block
}

output "integration_subnet_cidrs" {
  value = aws_subnet.integration[*].cidr_block
}
