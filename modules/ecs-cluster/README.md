# ecs-cluster

An ECS cluster on EC2 whose container instances scale with the tasks, in private subnets:

- ECS cluster (Container Insights off)
- Launch template on a pinned ECS-optimized AMI: IMDSv2 only with hop limit 1, encrypted gp3 root volume, user data that joins the cluster
- Auto Scaling group between `min_size` and `max_size`, scaled by an ECS capacity provider (managed scaling, termination protection and draining), set as the cluster default
- Instance role with only the ECS and SSM managed policies, under `/workload/` with the given permissions boundary
- Security group with no inbound rules. Access is through SSM Session Manager

The subnets need internet egress (NAT) so the agents can reach ECS, ECR and SSM.

## Usage

```hcl
module "ecs_cluster" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/ecs-cluster?ref=ecs-cluster/v0.2.0"

  name                     = "mdb-dev"
  vpc_id                   = data.aws_vpc.this.id
  subnet_ids               = data.aws_subnets.private.ids
  ami_id                   = "ami-08246d4dc9f74f0b7" # ECS-optimized AL2023 arm64
  instance_type            = "t4g.small"
  min_size                 = 0
  max_size                 = 2
  permissions_boundary_arn = data.aws_iam_policy.boundary.arn
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Cluster name and resource prefix |
| `vpc_id` | `string` | | VPC for the security group |
| `subnet_ids` | `list(string)` | | Private subnets with NAT egress |
| `ami_id` | `string` | | ECS-optimized AMI ID, pinned and bumped by PR |
| `instance_type` | `string` | `t4g.micro` | Must match the AMI's architecture |
| `min_size` | `number` | `1` | Fewest instances; 0 lets ECS stop all when no task needs one |
| `max_size` | `number` | `2` | Most instances ECS may scale out to |
| `permissions_boundary_arn` | `string` | | Boundary for the instance role |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Name of the ECS cluster |
| `cluster_arn` | ARN of the ECS cluster |
| `capacity_provider_name` | Capacity provider, also the cluster default |

## Testing

```bash
terraform init -backend=false
terraform test
```
