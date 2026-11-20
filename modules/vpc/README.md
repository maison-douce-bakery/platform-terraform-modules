# vpc

A VPC with public, private and database subnets across 2 or 3 AZs:

- VPC with DNS hostnames, and an internet gateway
- One public subnet per AZ, routed to the internet gateway. Instances get no public IP unless they ask for one
- One private subnet per AZ, each with its own route table. Internet egress through a NAT gateway when `nat_mode = "single"`
- One database subnet per AZ, sharing a route table with only the local route (no internet, no NAT)
- An S3 gateway endpoint on the private route tables (free, keeps S3 traffic off the NAT)
- The default security group locked down (no rules)

The `/16` is split into one `/18` per tier and one `/20` per AZ. The fourth `/18` is spare.

| Tier | Range (for `10.10.0.0/16`) | Created |
|---|---|---|
| public | `10.10.0.0/18` | Yes |
| private | `10.10.64.0/18` | Yes |
| database | `10.10.128.0/18` | Yes |

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/vpc?ref=vpc/v0.3.0"

  name       = "mdb-dev"
  cidr_block = "10.10.0.0/16"
  nat_mode   = "single"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Name prefix for every resource |
| `cidr_block` | `string` | | VPC CIDR, must be a `/16` |
| `az_count` | `number` | `2` | Number of AZs, 2 or 3 |
| `nat_mode` | `string` | `"none"` | `none`, or `single` for one NAT gateway (about $47/month with its public IP) |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `public_subnet_ids` | IDs of the public subnets, in AZ order |
| `private_subnet_ids` | IDs of the private subnets, in AZ order |
| `database_subnet_ids` | IDs of the database subnets, in AZ order. No route to the internet |

## Testing

```bash
terraform init -backend=false
terraform test
```
