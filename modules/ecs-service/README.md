# ecs-service

One container as an ECS Fargate service:

- Fargate task definition on ARM64 with `awsvpc` networking, image pinned by digest, valid cpu/memory pair enforced
- Optional public IPv4 per task (`assign_public_ip`) so tasks in public subnets reach the internet without a NAT
- Service with a deployment circuit breaker that rolls back, waiting for a steady state on apply
- Task security group: no inbound unless security groups are given (then only the container port). `container_port` may be null for containers that listen on none
- Execution role that may read only the given Secrets Manager secrets (and decrypt their KMS keys)
- Task role with no permissions unless the caller passes a policy
- Both roles under `/workload/` with the given permissions boundary, trusted only by this account's ECS
- Container logs in a `/ecs/<name>` log group with a retention
- Optional EFS volumes, mounted over TLS through an access point and authorized by the task role

## Usage

```hcl
module "app" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/ecs-service?ref=ecs-service/v0.3.0"

  name                     = "mdb-dev-app"
  cluster_name             = "mdb-dev"
  vpc_id                   = data.aws_vpc.this.id
  subnet_ids               = data.aws_subnets.public.ids
  image                    = "ghcr.io/org/app@sha256:..."
  container_port           = 8080
  assign_public_ip         = true
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
| `capacity_provider_name` | `string` | `FARGATE` | `FARGATE` or `FARGATE_SPOT` |
| `vpc_id` | `string` | | VPC for the task security group |
| `subnet_ids` | `list(string)` | | Subnets for the tasks (public when `assign_public_ip`) |
| `assign_public_ip` | `bool` | `false` | Public IPv4 per task, for egress without a NAT |
| `image` | `string` | | Image pinned by digest |
| `cpu` | `number` | `256` | Task CPU units: 256, 512, 1024, 2048, 4096 |
| `memory` | `number` | `512` | Task memory in MiB (hard limit); must be valid for `cpu` on Fargate |
| `container_port` | `number` | `null` | Container port; null means no port mapping and no ingress |
| `command` | `list(string)` | `null` | Override the image command |
| `environment` | `map(string)` | `{}` | Plain environment variables |
| `secrets` | `map(object)` | `{}` | Variables from Secrets Manager: `secret_arn`, optional `json_key` |
| `secrets_kms_key_arns` | `list(string)` | `[]` | KMS keys that encrypt the secrets |
| `ingress_security_group_ids` | `list(string)` | `[]` | Security groups allowed to reach the container port; empty when `container_port` is null |
| `task_role_policy_json` | `string` | `null` | Policy for the application's AWS calls |
| `desired_count` | `number` | `1` | Tasks to keep running |
| `deployment_minimum_healthy_percent` | `number` | `100` | Lower limit during a deployment; `0` with a maximum of `100` stops the old task first |
| `deployment_maximum_percent` | `number` | `200` | Upper limit during a deployment |
| `efs_volumes` | `map(object)` | `{}` | EFS volumes by name: `file_system_id`, `access_point_id`, `container_path`, optional `read_only` |
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
