# ecs-service

One container as an ECS service on an EC2 capacity provider:

- Task definition on ARM64 with `awsvpc` networking, image pinned by digest
- Service with a deployment circuit breaker that rolls back, waiting for a steady state on apply
- Task security group: inbound only from the given security groups on the container port
- Execution role that may read only the given Secrets Manager secrets (and decrypt their KMS keys)
- Task role with no permissions unless the caller passes a policy
- Both roles under `/workload/` with the given permissions boundary, trusted only by this account's ECS
- Container logs in a `/ecs/<name>` log group with a retention

## Usage

```hcl
module "app" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/ecs-service?ref=ecs-service/v0.1.0"

  name                     = "mdb-dev-app"
  cluster_name             = "mdb-dev"
  capacity_provider_name   = "mdb-dev-ec2"
  vpc_id                   = data.aws_vpc.this.id
  subnet_ids               = data.aws_subnets.private.ids
  image                    = "ghcr.io/org/app@sha256:..."
  container_port           = 8080
  permissions_boundary_arn = data.aws_iam_policy.boundary.arn

  environment = { LOG_LEVEL = "info" }
  secrets = {
    DB_PASSWORD = { secret_arn = data.aws_secretsmanager_secret.db.arn, json_key = "password" }
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Service name and resource prefix |
| `cluster_name` | `string` | | ECS cluster |
| `capacity_provider_name` | `string` | | Capacity provider for the tasks |
| `vpc_id` | `string` | | VPC for the task security group |
| `subnet_ids` | `list(string)` | | Private subnets for the tasks |
| `image` | `string` | | Image pinned by digest |
| `cpu` | `number` | `256` | Task CPU units |
| `memory` | `number` | `512` | Task memory in MiB (hard limit) |
| `container_port` | `number` | | Container port |
| `command` | `list(string)` | `null` | Override the image command |
| `environment` | `map(string)` | `{}` | Plain environment variables |
| `secrets` | `map(object)` | `{}` | Variables from Secrets Manager: `secret_arn`, optional `json_key` |
| `secrets_kms_key_arns` | `list(string)` | `[]` | KMS keys that encrypt the secrets |
| `ingress_security_group_ids` | `list(string)` | `[]` | Security groups allowed to reach the container port |
| `task_role_policy_json` | `string` | `null` | Policy for the application's AWS calls |
| `desired_count` | `number` | `1` | Tasks to keep running |
| `permissions_boundary_arn` | `string` | | Boundary for both roles |
| `log_retention_days` | `number` | `30` | Log retention |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `service_name` | ECS service name |
| `security_group_id` | Task security group, for the ingress of what the tasks call |
| `task_role_arn` | Application task role |
| `log_group_name` | Container log group |

## Testing

```bash
terraform init -backend=false
terraform test
```
