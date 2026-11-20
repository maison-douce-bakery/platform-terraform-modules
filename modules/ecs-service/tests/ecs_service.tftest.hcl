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
  capacity_provider_name   = "mdb-test-ec2"
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
    error_message = "Tasks must not get public IPs."
  }

  assert {
    condition     = one(aws_ecs_service.this.deployment_circuit_breaker).enable && one(aws_ecs_service.this.deployment_circuit_breaker).rollback
    error_message = "Failed deployments must roll back."
  }

  assert {
    condition     = one(aws_ecs_service.this.capacity_provider_strategy).capacity_provider == "mdb-test-ec2" && aws_ecs_service.this.wait_for_steady_state
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

run "rejects_tag_without_digest" {
  command = plan

  variables {
    image = "ghcr.io/example/app:latest"
  }

  expect_failures = [var.image]
}
