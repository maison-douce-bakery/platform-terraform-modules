resource "aws_security_group" "this" {
  name        = "${var.name}-task"
  description = "${var.name} tasks. Inbound only from the given security groups on the container port."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-task" })
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = toset(var.ingress_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Container port from ${each.value}"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Egress through the NAT and to VPC services"
}
