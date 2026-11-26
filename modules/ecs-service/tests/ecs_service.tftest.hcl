# Mocked AWS: no credentials, no cost. The provider validates these IDs, so mocks return real-looking ones.
mock_provider "aws" {
  override_data {
    target = data.aws_region.current
    values = { region = "ap-southeast-2" }
  }

  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "123456789012" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/workload/mdb-test-app" }
  }

  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:ap-southeast-2:123456789012:task-definition/mdb-test-app:1" }
  }
}

variables {
  name                     = "mdb-test-app"
  cluster_name             = "mdb-test"
  vpc_id                   = "vpc-0123456789abcdef0"
  subnet_ids               = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  image                    = "ghcr.io/example/app@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  container_port           = 8080
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/platform/boundary"
  environment              = { LOG_LEVEL = "info" }
  secrets = {
    DB_PASSWORD = { secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:db-AbCdEf", json_key = "password" }
    API_KEY     = { secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:api-GhIjKl" }
  }
  secrets_kms_key_arns       = ["arn:aws:kms:ap-southeast-2:123456789012:key/11111111-2222-3333-4444-555555555555"]
  ingress_security_group_ids = ["sg-0aaaaaaaaaaaaaaaa"]
}

run "defaults" {
  assert {
    condition     = aws_ecs_task_definition.this.network_mode == "awsvpc" && aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "Tasks must use awsvpc on ARM64."
  }

  assert {
    condition     = !one(aws_ecs_service.this.network_configuration).assign_public_ip
    error_message = "Tasks must not get public IPs by default."
  }

  assert {
    condition     = aws_ecs_task_definition.this.requires_compatibilities == toset(["FARGATE"]) && aws_ecs_task_definition.this.cpu == "256" && aws_ecs_task_definition.this.memory == "512"
    error_message = "Tasks must be Fargate with task-level cpu and memory."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings == [{ containerPort = 8080, protocol = "tcp" }]
    error_message = "The container port must be mapped."
  }

  assert {
    condition     = one(aws_ecs_service.this.deployment_circuit_breaker).enable && one(aws_ecs_service.this.deployment_circuit_breaker).rollback
    error_message = "Failed deployments must roll back."
  }

  assert {
    condition     = one(aws_ecs_service.this.capacity_provider_strategy).capacity_provider == "FARGATE" && aws_ecs_service.this.wait_for_steady_state
    error_message = "The service must use the capacity provider and wait for a steady state."
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets == [
      { name = "API_KEY", valueFrom = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:api-GhIjKl" },
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:db-AbCdEf:password::" },
    ]
    error_message = "Secrets must be injected as valueFrom references, with the JSON key when given."
  }

  assert {
    condition     = !strcontains(aws_ecs_task_definition.this.container_definitions, "\"value\":\"arn:aws:secretsmanager")
    error_message = "Secret ARNs must never be passed as plain environment values."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[0].Resource) == toset(["arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:db-AbCdEf", "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:api-GhIjKl"])
    error_message = "The execution role may read only the given secrets."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.execution_secrets[0].policy).Statement[1].Action == "kms:Decrypt"
    error_message = "The execution role must be able to decrypt the secrets' KMS key."
  }

  assert {
    condition     = length(aws_iam_role_policy.execution_ssm) == 0
    error_message = "Without ssm_secrets there must be no SSM policy."
  }

  assert {
    condition     = length(aws_iam_role_policy.task) == 0
    error_message = "The task role must have no permissions by default."
  }

  assert {
    condition = alltrue([
      for r in [aws_iam_role.execution, aws_iam_role.task] :
      r.path == "/workload/" && r.permissions_boundary == var.permissions_boundary_arn && jsondecode(r.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012"
    ])
    error_message = "Both roles must live under /workload/, carry the boundary and trust only this account's ECS."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1 && aws_vpc_security_group_ingress_rule.this["sg-0aaaaaaaaaaaaaaaa"].from_port == 8080 && aws_vpc_security_group_ingress_rule.this["sg-0aaaaaaaaaaaaaaaa"].to_port == 8080
    error_message = "Ingress must be only the container port from the given security groups."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-group"] == "/ecs/mdb-test-app" && aws_cloudwatch_log_group.this.retention_in_days == 30
    error_message = "Logs must go to the module's log group with a retention."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_minimum_healthy_percent == 100 && aws_ecs_service.this.deployment_maximum_percent == 200
    error_message = "By default a new task must start before the old one stops."
  }

  assert {
    condition     = length(aws_ecs_task_definition.this.volume) == 0 && !can(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].mountPoints) && length(aws_iam_role_policy.task_efs) == 0
    error_message = "Without EFS volumes there must be no volume, mount point or EFS policy."
  }

  assert {
    condition     = !aws_ecs_service.this.enable_execute_command && length(aws_iam_role_policy.task_exec) == 0 && !can(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].linuxParameters)
    error_message = "ECS Exec must be off by default: no service flag, no exec policy, no linuxParameters."
  }
}

run "execute_command" {
  variables {
    enable_execute_command = true
  }

  assert {
    condition     = aws_ecs_service.this.enable_execute_command
    error_message = "The service must enable ECS Exec."
  }

  assert {
    condition = toset(jsondecode(aws_iam_role_policy.task_exec[0].policy).Statement[0].Action) == toset([
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]) && length(jsondecode(aws_iam_role_policy.task_exec[0].policy).Statement[0].Action) == 4
    error_message = "The task role must get exactly the four ssmmessages actions."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].linuxParameters.initProcessEnabled
    error_message = "ECS Exec needs initProcessEnabled."
  }
}

run "public_ip_and_spot" {
  variables {
    assign_public_ip       = true
    capacity_provider_name = "FARGATE_SPOT"
  }

  assert {
    condition     = one(aws_ecs_service.this.network_configuration).assign_public_ip && one(aws_ecs_service.this.capacity_provider_strategy).capacity_provider == "FARGATE_SPOT"
    error_message = "assign_public_ip and the capacity provider must come from the inputs."
  }
}

run "valid_fargate_sizes" {
  variables {
    cpu    = 1024
    memory = 8192
  }

  assert {
    condition     = aws_ecs_task_definition.this.cpu == "1024" && aws_ecs_task_definition.this.memory == "8192"
    error_message = "A valid cpu/memory pair must be accepted."
  }
}

run "rejects_invalid_cpu_memory" {
  command = plan

  variables {
    cpu    = 256
    memory = 4096
  }

  expect_failures = [var.memory]
}

run "rejects_unknown_cpu" {
  command = plan

  variables {
    cpu    = 300
    memory = 512
  }

  expect_failures = [var.memory]
}

run "no_container_port" {
  variables {
    container_port             = null
    ingress_security_group_ids = []
  }

  assert {
    condition     = !can(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings)
    error_message = "Without a container port there must be no portMappings."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "Without a container port there must be no ingress rules."
  }
}

run "rejects_ingress_without_port" {
  command = plan

  variables {
    container_port = null
  }

  expect_failures = [var.ingress_security_group_ids]
}

run "efs_volume_single_copy" {
  variables {
    deployment_minimum_healthy_percent = 0
    deployment_maximum_percent         = 100
    efs_volumes = {
      data = { file_system_id = "fs-0123456789abcdef0", access_point_id = "fsap-0123456789abcdef0", container_path = "/var/lib/app" }
      ref  = { file_system_id = "fs-0123456789abcdef0", access_point_id = "fsap-0fedcba9876543210", container_path = "/ref", read_only = true }
    }
  }

  assert {
    condition     = aws_ecs_service.this.deployment_minimum_healthy_percent == 0 && aws_ecs_service.this.deployment_maximum_percent == 100
    error_message = "The deployment limits must come from the inputs."
  }

  assert {
    condition = alltrue([
      for v in aws_ecs_task_definition.this.volume :
      one(v.efs_volume_configuration).transit_encryption == "ENABLED" && one(one(v.efs_volume_configuration).authorization_config).iam == "ENABLED"
    ]) && length(aws_ecs_task_definition.this.volume) == 2
    error_message = "EFS volumes must use TLS and IAM authorization."
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].mountPoints == [
      { sourceVolume = "data", containerPath = "/var/lib/app", readOnly = false },
      { sourceVolume = "ref", containerPath = "/ref", readOnly = true },
    ]
    error_message = "Each volume must be mounted at its container path."
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.task_efs[0].policy).Statement == [
      {
        Effect    = "Allow"
        Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
        Resource  = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:file-system/fs-0123456789abcdef0"
        Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:access-point/fsap-0123456789abcdef0" } }
      },
      {
        Effect    = "Allow"
        Action    = ["elasticfilesystem:ClientMount"]
        Resource  = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:file-system/fs-0123456789abcdef0"
        Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:access-point/fsap-0fedcba9876543210" } }
      },
    ]
    error_message = "The task role may mount each file system only through its access point, and write only to writable volumes."
  }
}

run "rejects_minimum_above_100" {
  command = plan

  variables {
    deployment_minimum_healthy_percent = 150
  }

  expect_failures = [var.deployment_minimum_healthy_percent]
}

run "no_secrets_no_secret_policy" {
  variables {
    secrets              = {}
    secrets_kms_key_arns = []
  }

  assert {
    condition     = length(aws_iam_role_policy.execution_secrets) == 0
    error_message = "Without secrets there must be no secrets policy."
  }
}

run "ssm_secrets" {
  variables {
    ssm_secrets = {
      COGNITO_SECRET = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/cognito"
      APP_KEY        = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/app-key"
    }
    secrets_kms_key_arns = []
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets == [
      { name = "API_KEY", valueFrom = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:api-GhIjKl" },
      { name = "APP_KEY", valueFrom = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/app-key" },
      { name = "COGNITO_SECRET", valueFrom = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/cognito" },
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:db-AbCdEf:password::" },
    ]
    error_message = "SSM and Secrets Manager secrets must be merged and sorted by name, as valueFrom references."
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.execution_ssm[0].policy).Statement == [{
      Effect = "Allow"
      Action = "ssm:GetParameters"
      Resource = [
        "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/app-key",
        "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/cognito",
      ]
    }]
    error_message = "The execution role may read exactly the given parameters and nothing else, with no KMS statement for AWS managed keys."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.execution_ssm[0].policy, "\"*\"") && !strcontains(aws_ecs_task_definition.this.container_definitions, "\"value\":\"arn:aws:ssm")
    error_message = "No wildcard resources and no parameter ARN as a plain environment value."
  }
}

run "ssm_secrets_with_kms" {
  variables {
    ssm_secrets = { APP_KEY = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/app-key" }
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.execution_ssm[0].policy).Statement[1] == { Effect = "Allow", Action = "kms:Decrypt", Resource = ["arn:aws:kms:ap-southeast-2:123456789012:key/11111111-2222-3333-4444-555555555555"] }
    error_message = "With customer managed keys the SSM policy must allow kms:Decrypt on exactly those keys."
  }
}

run "rejects_overlapping_secret_names" {
  command = plan

  variables {
    ssm_secrets = { DB_PASSWORD = "arn:aws:ssm:ap-southeast-2:123456789012:parameter/mdb/prod/db" }
  }

  expect_failures = [var.ssm_secrets]
}

run "rejects_non_ssm_arn" {
  command = plan

  variables {
    ssm_secrets = { APP_KEY = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:x-AbCdEf" }
  }

  expect_failures = [var.ssm_secrets]
}

run "rejects_tag_without_digest" {
  command = plan

  variables {
    image = "ghcr.io/example/app:latest"
  }

  expect_failures = [var.image]
}
