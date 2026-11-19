# Mocked AWS: no credentials, no cost.
mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.this
    values = {
      names = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
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
