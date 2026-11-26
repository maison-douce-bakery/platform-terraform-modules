data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  secret_arns = distinct([for s in values(var.secrets) : s.secret_arn])

  # Secrets Manager and SSM references in one map; the names cannot overlap (validated).
  secret_refs = merge(
    { for k, v in var.secrets : k => v.json_key == null ? v.secret_arn : "${v.secret_arn}:${v.json_key}::" },
    var.ssm_secrets,
  )

  container = merge(
    {
      name        = var.name
      image       = var.image
      essential   = true
      environment = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
      secrets     = [for k in sort(keys(local.secret_refs)) : { name = k, valueFrom = local.secret_refs[k] }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    },
    var.container_port == null ? {} : { portMappings = [{ containerPort = var.container_port, protocol = "tcp" }] },
    var.command == null ? {} : { command = var.command },
    # ECS Exec sessions need an init process to reap their child processes.
    var.enable_execute_command ? { linuxParameters = { initProcessEnabled = true } } : {},
    length(var.efs_volumes) == 0 ? {} : {
      mountPoints = [
        for k in sort(keys(var.efs_volumes)) : {
          sourceVolume  = k
          containerPath = var.efs_volumes[k].container_path
          readOnly      = var.efs_volumes[k].read_only
        }
      ]
    },
  )

  # Only ECS in this account may assume the roles (confused deputy protection).
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}
