# AMI data source — only runs when ami_id_override is not set (real AWS).
# In Ministack, set ami_id_override in the live config to skip this.
data "aws_ami" "amazon_linux" {
  count       = var.ami_id_override == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC/subnet data sources — only run when create_instance is true
# and no explicit IDs are provided. Ministack staging has no default VPC,
# so these must not run when create_instance = false.
data "aws_vpc" "default" {
  count   = var.create_instance && var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.create_instance && var.subnet_id == "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id]
  }
}

locals {
  ami_id    = var.ami_id_override != "" ? var.ami_id_override : data.aws_ami.amazon_linux[0].id
  subnet_id = var.subnet_id != "" ? var.subnet_id : (length(data.aws_subnets.default) > 0 ? data.aws_subnets.default[0].ids[0] : "")
  vpc_id    = var.vpc_id != "" ? var.vpc_id : (length(data.aws_vpc.default) > 0 ? data.aws_vpc.default[0].id : "")
}

# Security group and instance are skipped when create_instance = false.
# IAM resources (iam.tf) always apply — that is the pattern being tested.
resource "aws_security_group" "instance" {
  count = var.create_instance ? 1 : 0

  name        = "${var.project}-${var.environment}-ec2-instance"
  description = "EC2 instance - no inbound, SSM session manager only"
  vpc_id      = local.vpc_id

  egress {
    description = "All outbound - SSM, CloudWatch, package manager, HTTPS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "this" {
  count = var.create_instance ? 1 : 0

  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance[0].id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = false

  # IMDSv2: require a session token before credentials are served.
  # Blocks SSRF attacks that try to reach 169.254.169.254 directly (v1 path).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.enable_imdsv2 ? "required" : "optional"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = var.encrypt_root_volume
    delete_on_termination = true
  }

  # Runs once at first boot. Not executed in Ministack (no real VM),
  # but correct for real AWS. CloudWatch agent + SSM agent bootstrap.
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail

    # Install CloudWatch agent and pull config from SSM Parameter Store
    yum install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s \
      -c ssm:/${var.project}/${var.environment}/cloudwatch-agent-config || true

    # SSM agent is pre-installed on AL2023 — ensure it is running
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOT
  )

  tags = {
    Name        = "${var.project}-${var.environment}-ec2"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
