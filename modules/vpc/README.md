# vpc

A VPC with public subnets across 2 or 3 AZs:

- VPC with DNS hostnames, and an internet gateway
- One public subnet per AZ, routed to the internet gateway. Instances get no public IP unless they ask for one
- The default security group locked down (no rules)

The `/16` is split into one `/18` per tier and one `/20` per AZ. Private and database ranges are reserved for later versions.

| Tier | Range (for `10.10.0.0/16`) | Created |
|---|---|---|
| public | `10.10.0.0/18` | Yes |
| private | `10.10.64.0/18` | No |
| database | `10.10.128.0/18` | No |

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/maison-douce-bakery/platform-terraform-modules.git//modules/vpc?ref=vpc/v0.1.0"

  name       = "mdb-dev"
  cidr_block = "10.10.0.0/16"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | | Name prefix for every resource |
| `cidr_block` | `string` | | VPC CIDR, must be a `/16` |
| `az_count` | `number` | `2` | Number of AZs, 2 or 3 |
| `tags` | `map(string)` | `{}` | Extra tags on top of the provider's `default_tags` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `public_subnet_ids` | IDs of the public subnets, in AZ order |

## Testing

```bash
terraform init -backend=false
terraform test
```
