# Mocked AWS: no credentials, no cost.
mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.this
    values = {
      names = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
    }
  }

  override_data {
    target = data.aws_region.current
    values = {
      region = "ap-southeast-2"
    }
  }
}

variables {
  name       = "mdb-test"
  cidr_block = "10.10.0.0/16"
}

run "defaults" {
  assert {
    condition = local.public_subnets == {
      "ap-southeast-2a" = "10.10.0.0/20"
      "ap-southeast-2b" = "10.10.16.0/20"
    }
    error_message = "Public subnets must be the first two /20s in AZs a and b."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : !s.map_public_ip_on_launch])
    error_message = "Public subnets must not assign public IPs on launch."
  }

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0" && aws_route.public_internet.gateway_id == aws_internet_gateway.this.id
    error_message = "The public route table must send 0.0.0.0/0 to the IGW."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 2
    error_message = "Every public subnet must use the public route table."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames
    error_message = "DNS hostnames must be enabled."
  }

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "The default security group must have no rules."
  }

  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "public_subnet_ids must list both subnets."
  }
}

run "third_az_keeps_existing_subnets" {
  variables {
    az_count = 3
  }

  assert {
    condition = local.public_subnets == {
      "ap-southeast-2a" = "10.10.0.0/20"
      "ap-southeast-2b" = "10.10.16.0/20"
      "ap-southeast-2c" = "10.10.32.0/20"
    }
    error_message = "Adding an AZ must not move existing subnets."
  }

  assert {
    condition = local.private_subnets == {
      "ap-southeast-2a" = "10.10.64.0/20"
      "ap-southeast-2b" = "10.10.80.0/20"
      "ap-southeast-2c" = "10.10.96.0/20"
    }
    error_message = "Adding an AZ must not move existing private subnets."
  }

  assert {
    condition = local.database_subnets == {
      "ap-southeast-2a" = "10.10.128.0/20"
      "ap-southeast-2b" = "10.10.144.0/20"
      "ap-southeast-2c" = "10.10.160.0/20"
    }
    error_message = "Adding an AZ must not move existing database subnets."
  }
}

run "database_tier_is_isolated" {
  variables {
    nat_mode = "single"
  }

  assert {
    condition = local.database_subnets == {
      "ap-southeast-2a" = "10.10.128.0/20"
      "ap-southeast-2b" = "10.10.144.0/20"
    }
    error_message = "Database subnets must be the first two /20s of the database /18."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.database : !s.map_public_ip_on_launch])
    error_message = "Database subnets must not assign public IPs."
  }

  assert {
    condition     = length(aws_route_table_association.database) == 2 && alltrue([for a in aws_route_table_association.database : a.route_table_id == aws_route_table.database.id])
    error_message = "Every database subnet must use the database route table."
  }

  assert {
    condition     = alltrue([for r in aws_route.private_nat : r.route_table_id != aws_route_table.database.id]) && aws_route.public_internet.route_table_id != aws_route_table.database.id
    error_message = "The database route table must have no route to a NAT or the internet gateway."
  }

  assert {
    condition     = !contains(aws_vpc_endpoint.s3.route_table_ids, aws_route_table.database.id)
    error_message = "The database route table must not be attached to the S3 endpoint."
  }

  assert {
    condition     = length(output.database_subnet_ids) == 2
    error_message = "database_subnet_ids must list both subnets."
  }
}

run "private_tier_without_nat" {
  assert {
    condition = local.private_subnets == {
      "ap-southeast-2a" = "10.10.64.0/20"
      "ap-southeast-2b" = "10.10.80.0/20"
    }
    error_message = "Private subnets must be the first two /20s of the private /18."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    error_message = "Private subnets must not assign public IPs."
  }

  assert {
    condition     = length(aws_route_table.private) == 2 && length(aws_route_table_association.private) == 2
    error_message = "Each private subnet must have its own route table."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0 && length(aws_route.private_nat) == 0
    error_message = "nat_mode none must create no NAT, EIP or default route."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.service_name == "com.amazonaws.ap-southeast-2.s3" && aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "The S3 endpoint must be a gateway endpoint in the VPC's region."
  }

  assert {
    condition     = toset(aws_vpc_endpoint.s3.route_table_ids) == toset(values(aws_route_table.private)[*].id)
    error_message = "The S3 endpoint must be attached to every private route table."
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "private_subnet_ids must list both subnets."
  }
}

run "single_nat" {
  variables {
    nat_mode = "single"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && aws_nat_gateway.this[0].subnet_id == aws_subnet.public["ap-southeast-2a"].id
    error_message = "nat_mode single must create one NAT in the first public subnet."
  }

  assert {
    condition = alltrue([
      for k, rt in aws_route_table.private :
      aws_route.private_nat[k].route_table_id == rt.id && aws_route.private_nat[k].nat_gateway_id == aws_nat_gateway.this[0].id && aws_route.private_nat[k].destination_cidr_block == "0.0.0.0/0"
    ])
    error_message = "Every private route table must send 0.0.0.0/0 to the NAT."
  }
}

run "rejects_unknown_nat_mode" {
  command = plan

  variables {
    nat_mode = "per_az"
  }

  expect_failures = [var.nat_mode]
}

run "rejects_non_16_cidr" {
  command = plan

  variables {
    cidr_block = "10.10.0.0/24"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "MDB_Dev"
  }

  expect_failures = [var.name]
}
