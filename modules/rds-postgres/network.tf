resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# No rules here: each consumer stack adds its own 5432 ingress from its security group.
resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "${var.name} PostgreSQL. Ingress is added by consumers."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-rds" })
}
