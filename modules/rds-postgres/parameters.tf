resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-postgres${local.major_version}"
  family = "postgres${local.major_version}"

  # AWS reports this parameter back as pending-reboot; "immediate" (the default) would show a diff forever.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
