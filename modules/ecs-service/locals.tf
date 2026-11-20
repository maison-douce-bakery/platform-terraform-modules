data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  secret_arns = distinct([for s in values(var.secrets) : s.secret_arn])

  container = merge(
    {
      name         = var.name
      image        = var.image
      essential    = true
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
      environment  = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
      secrets = [
        for k in sort(keys(var.secrets)) : {
          name      = k
          valueFrom = var.secrets[k].json_key == null ? var.secrets[k].secret_arn : "${var.secrets[k].secret_arn}:${var.secrets[k].json_key}::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    },
    var.command == null ? {} : { command = var.command },
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
