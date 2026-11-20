resource "aws_kms_key" "this" {
  description             = "${var.name} RDS storage, snapshots and master user secret"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.this.key_id
}
