# rds-postgres

A private, encrypted PostgreSQL instance on Amazon RDS:

- PostgreSQL 18 with automatic minor upgrades, gp3 storage with autoscaling
- Its own KMS key (rotation on) for storage, snapshots and the master user secret
- Master password generated and stored by RDS in Secrets Manager, never in Terraform state
- `rds.force_ssl = 1`, not publicly accessible, in the given database subnets
- Deletion protection, a final snapshot on delete, 7-day automated backups kept after delete
- PostgreSQL and upgrade logs exported to CloudWatch log groups with a retention
- A security group with no inbound rules. Each consumer adds its own 5432 rule

## Usage

```hcl
module "rds" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/rds-postgres?ref=rds-postgres/v0.1.0"

  name           = "mdb-dev"
  vpc_id         = data.aws_vpc.this.id
  subnet_ids     = data.aws_subnets.database.ids
  instance_class = "db.t4g.micro"
  multi_az       = false
}

# In a consumer stack
resource "aws_vpc_security_group_ingress_rule" "app_to_db" {
  security_group_id            = data.aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Instance identifier and resource prefix |
| `vpc_id` | `string` | | VPC for the security group |
| `subnet_ids` | `list(string)` | | Database subnets in at least two AZs |
| `instance_class` | `string` | | DB instance class |
| `multi_az` | `bool` | | Synchronous standby in a second AZ |
| `engine_version` | `string` | `"18"` | Major version, or an exact version |
| `allocated_storage` | `number` | `20` | Initial storage in GiB |
| `max_allocated_storage` | `number` | `100` | Storage autoscaling limit in GiB |
| `backup_retention_days` | `number` | `7` | Automated backup retention (1-35) |
| `log_retention_days` | `number` | `30` | CloudWatch log retention |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `address` | Hostname of the instance |
| `port` | PostgreSQL port |
| `security_group_id` | Security group to add consumer ingress rules to |
| `master_user_secret_arn` | Secrets Manager ARN of the master credentials |

## Testing

```bash
terraform init -backend=false
terraform test
```
