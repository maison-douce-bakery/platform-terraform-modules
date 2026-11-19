resource "aws_vpc" "this" {
  cidr_block = var.cidr_block

  # Needed for private DNS (SSM, endpoints, RDS).
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

# No rules: removes the default allow rules so nothing uses it by accident (CIS 5.4).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default-do-not-use" })
}
