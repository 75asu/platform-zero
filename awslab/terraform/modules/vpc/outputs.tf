output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "Internet gateway ID"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (ALB tier)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (ECS/EC2 tier)"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of data subnets (RDS tier)"
  value       = aws_subnet.data[*].id
}

output "public_route_table_id" {
  description = "Route table ID for public subnets"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Route table IDs for private subnets (one per AZ)"
  value       = aws_route_table.private[*].id
}

output "data_route_table_ids" {
  description = "Route table IDs for data subnets (one per AZ)"
  value       = aws_route_table.data[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (empty when enable_nat_gateway = false)"
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs assigned to NAT gateways"
  value       = aws_eip.nat[*].public_ip
}

output "default_security_group_id" {
  description = "Default security group ID (locked down — do not attach to resources). Empty string when lockdown_default_sg = false."
  value       = length(aws_default_security_group.default) > 0 ? aws_default_security_group.default[0].id : ""
}
