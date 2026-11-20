resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  multi_az       = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.this.arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  # RDS generates and rotates the password in Secrets Manager; it never reaches Terraform state.
  username                      = "dbadmin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.this.arn

  backup_retention_period  = var.backup_retention_days
  backup_window            = "15:00-16:00"
  maintenance_window       = "sun:16:30-sun:17:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-final"

  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = local.log_exports

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.this]
}
