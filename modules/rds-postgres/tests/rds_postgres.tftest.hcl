# Mocked AWS: no credentials, no cost. The provider validates these IDs, so mocks return real-looking ones.
mock_provider "aws" {
  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:ap-southeast-2:123456789012:key/11111111-2222-3333-4444-555555555555"
      key_id = "11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:rds!db-abc-123456"
        kms_key_id    = "arn:aws:kms:ap-southeast-2:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_status = "active"
      }]
    }
  }
}

variables {
  name           = "mdb-test"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  instance_class = "db.t4g.micro"
  multi_az       = false
}

run "defaults" {
  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.kms_key_id == aws_kms_key.this.arn
    error_message = "Storage must be encrypted with the module's KMS key."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation && aws_kms_key.this.deletion_window_in_days == 30
    error_message = "The KMS key must rotate and have a 30-day deletion window."
  }

  assert {
    condition     = !aws_db_instance.this.publicly_accessible
    error_message = "The DB instance must not be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot && aws_db_instance.this.final_snapshot_identifier == "mdb-test-final"
    error_message = "Deletion protection and a final snapshot must be on."
  }

  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7 && !aws_db_instance.this.delete_automated_backups && aws_db_instance.this.copy_tags_to_snapshot
    error_message = "Backups must be kept 7 days, survive deletion and carry tags."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.master_user_secret_kms_key_id == aws_kms_key.this.arn
    error_message = "RDS must manage the master password, encrypted with the module's key."
  }

  assert {
    condition     = one([for p in aws_db_parameter_group.this.parameter : p.value if p.name == "rds.force_ssl"]) == "1" && aws_db_parameter_group.this.family == "postgres18"
    error_message = "The parameter group must force SSL and match the major version."
  }

  assert {
    condition     = one([for p in aws_db_parameter_group.this.parameter : p.apply_method if p.name == "rds.force_ssl"]) == "pending-reboot"
    error_message = "rds.force_ssl must use pending-reboot, as AWS reports it, to avoid a permanent diff."
  }

  assert {
    condition     = length(aws_security_group.this.ingress) == 0
    error_message = "The security group must have no inbound rules; consumers add their own."
  }

  assert {
    condition     = aws_db_instance.this.storage_type == "gp3" && aws_db_instance.this.max_allocated_storage == 100
    error_message = "Storage must be gp3 with autoscaling."
  }

  assert {
    condition     = toset(keys(aws_cloudwatch_log_group.this)) == toset(aws_db_instance.this.enabled_cloudwatch_logs_exports) && alltrue([for g in aws_cloudwatch_log_group.this : g.retention_in_days == 30])
    error_message = "Every exported log must have a managed log group with 30-day retention."
  }

  assert {
    condition     = output.master_user_secret_arn != "" && output.security_group_id == aws_security_group.this.id
    error_message = "Outputs must expose the master secret and the security group."
  }
}

run "exact_engine_version_keeps_family" {
  variables {
    engine_version = "18.6"
  }

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres18"
    error_message = "An exact version must map to the major-version family."
  }
}

run "rejects_one_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0123456789abcdef0"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_storage_cap_below_size" {
  command = plan

  variables {
    max_allocated_storage = 10
  }

  expect_failures = [var.max_allocated_storage]
}

run "rejects_zero_backups" {
  command = plan

  variables {
    backup_retention_days = 0
  }

  expect_failures = [var.backup_retention_days]
}
