# ecs-cluster

A Fargate-only ECS cluster:

- ECS cluster (Container Insights off)
- Capacity providers `FARGATE` and `FARGATE_SPOT`, with `FARGATE` as the default strategy

AWS runs the hosts, so there is no AMI, Auto Scaling group or instance role.

## Usage

```hcl
module "ecs_cluster" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/ecs-cluster?ref=ecs-cluster/v0.3.0"

  name = "mdb-dev"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Cluster name and resource prefix |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Name of the ECS cluster |
| `cluster_arn` | ARN of the ECS cluster |

## Testing

```bash
terraform init -backend=false
terraform test
```
