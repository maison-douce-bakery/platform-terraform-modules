# ecs-cluster

An ECS cluster on EC2 with a fixed number of container instances in private subnets:

- ECS cluster (Container Insights off)
- Launch template on a pinned ECS-optimized AMI: IMDSv2 only with hop limit 1, encrypted gp3 root volume, user data that joins the cluster
- Auto Scaling group with exactly `instance_count` instances
- Instance role with only the ECS and SSM managed policies, under `/workload/` with the given permissions boundary
- Security group with no inbound rules. Access is through SSM Session Manager

The subnets need internet egress (NAT) so the agents can reach ECS, ECR and SSM.

## Usage

```hcl
module "ecs_cluster" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/ecs-cluster?ref=ecs-cluster/v0.1.0"

  name                     = "mdb-dev"
  vpc_id                   = data.aws_vpc.this.id
  subnet_ids               = data.aws_subnets.private.ids
  ami_id                   = "ami-08246d4dc9f74f0b7" # ECS-optimized AL2023 arm64
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
| `instance_count` | `number` | `1` | Fixed instance count, 0 to stop all |
| `permissions_boundary_arn` | `string` | | Boundary for the instance role |
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
