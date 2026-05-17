locals {
  # How many NAT gateways to create: one per AZ or one shared.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

# ── Internet gateway ───────────────────────────────────────────────────────────
# Required for public subnets to reach the internet and to anchor NAT gateways.

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

# ── Public subnets ─────────────────────────────────────────────────────────────
# One per AZ. Hosts: ALB, NAT gateway EIPs.
# map_public_ip_on_launch = false — instances here still don't need public IPs;
# the ALB handles inbound. NAT GW gets its own EIP.

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  # Tag required for AWS Load Balancer Controller to discover internet-facing subnets.
  tags = merge(local.common_tags, {
    Name                     = "${var.name}-public-${var.azs[count.index]}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

# ── Private subnets ────────────────────────────────────────────────────────────
# One per AZ. Hosts: ECS tasks, EC2 app instances.
# Outbound via NAT gateway (when enabled); otherwise local + VPC endpoints only.

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  # Tag required for internal load balancers via AWS Load Balancer Controller.
  tags = merge(local.common_tags, {
    Name                              = "${var.name}-private-${var.azs[count.index]}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ── Data subnets ───────────────────────────────────────────────────────────────
# One per AZ. Hosts: RDS, ElastiCache, OpenSearch.
# No route to the internet — data tier is isolated within the VPC.

resource "aws_subnet" "data" {
  count = length(var.data_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.data_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name}-data-${var.azs[count.index]}"
    Tier = "data"
  })
}

# ── NAT gateway ────────────────────────────────────────────────────────────────
# One EIP + NAT GW per AZ (or one shared when single_nat_gateway = true).
# Only created when enable_nat_gateway = true.

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ── Route tables ───────────────────────────────────────────────────────────────

# Public: default route → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private: default route → NAT GW (one per AZ when multiple NAT GWs, or shared).
# When NAT is disabled: no default route — traffic stays within VPC.
resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data: no default route — completely isolated.
# Inbound connections from private subnet only (enforced by security groups).
resource "aws_route_table" "data" {
  count = length(var.data_subnets)

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-data-rt-${count.index}"
  })
}

resource "aws_route_table_association" "data" {
  count = length(var.data_subnets)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[count.index].id
}

# ── Default security group lockdown ────────────────────────────────────────────
# The default SG allows all traffic between members by default — revoke that.
# Every resource should use an explicit, minimal SG instead.

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-default-sg-DO-NOT-USE"
  })
}

# ── VPC flow logs ──────────────────────────────────────────────────────────────

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = var.flow_logs_traffic_type
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn

  tags = merge(local.common_tags, {
    Name = "${var.name}-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = var.cloudwatch_log_group_name != "" ? var.cloudwatch_log_group_name : "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}
