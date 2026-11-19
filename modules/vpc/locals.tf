# No state filter: dropping an impaired AZ would shift the list and move subnets.
data "aws_availability_zones" "this" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(sort(data.aws_availability_zones.this.names), 0, var.az_count)

  # /16 -> one /18 per tier -> one /20 per AZ. Never renumber: existing subnets would move.
  # private and database are reserved, not created yet.
  tier_index = {
    public   = 0
    private  = 1
    database = 2
  }

  public_subnets = {
    for i, az in local.azs :
    az => cidrsubnet(cidrsubnet(var.cidr_block, 2, local.tier_index.public), 2, i)
  }
}
