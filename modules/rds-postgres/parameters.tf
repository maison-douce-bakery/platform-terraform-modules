resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-postgres${local.major_version}"
  family = "postgres${local.major_version}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
