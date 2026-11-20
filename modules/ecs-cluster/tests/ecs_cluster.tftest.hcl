# Mocked AWS: no credentials, no cost.
mock_provider "aws" {
  override_data {
    target = data.aws_default_tags.current
    values = {
      tags = { Project = "mdb", Environment = "test" }
    }
  }

  # The provider validates these IDs, so the mocks must return real-looking ones.
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/workload/mdb-test-ecs-instance"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 1
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }

  mock_resource "aws_autoscaling_group" {
    defaults = {
      arn = "arn:aws:autoscaling:ap-southeast-2:123456789012:autoScalingGroup:11111111-2222-3333-4444-555555555555:autoScalingGroupName/mdb-test-ecs"
    }
  }
}

variables {
  name                     = "mdb-test"
  vpc_id                   = "vpc-0123456789abcdef0"
  subnet_ids               = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ami_id                   = "ami-0123456789abcdef0"
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/platform/boundary"
}

run "defaults" {
  assert {
    condition     = aws_launch_template.this.instance_type == "t4g.micro" && aws_launch_template.this.image_id == var.ami_id
    error_message = "The launch template must use the pinned AMI and t4g.micro by default."
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required" && aws_launch_template.this.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "IMDSv2 must be required with hop limit 1."
  }

  assert {
    condition     = aws_launch_template.this.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.this.user_data), "ECS_CLUSTER=mdb-test") && strcontains(base64decode(aws_launch_template.this.user_data), "ECS_AWSVPC_BLOCK_IMDS=true")
    error_message = "User data must join the cluster and block IMDS for awsvpc tasks."
  }

  assert {
    condition     = aws_autoscaling_group.this.min_size == 1 && aws_autoscaling_group.this.max_size == 2
    error_message = "The ASG must default to 1-2 instances."
  }

  assert {
    condition     = aws_autoscaling_group.this.protect_from_scale_in
    error_message = "Instances must be protected from scale-in so ECS decides which ones may go."
  }

  assert {
    condition = (
      aws_ecs_capacity_provider.this.auto_scaling_group_provider[0].managed_termination_protection == "ENABLED" &&
      aws_ecs_capacity_provider.this.auto_scaling_group_provider[0].managed_draining == "ENABLED" &&
      aws_ecs_capacity_provider.this.auto_scaling_group_provider[0].managed_scaling[0].status == "ENABLED" &&
      aws_ecs_capacity_provider.this.auto_scaling_group_provider[0].managed_scaling[0].target_capacity == 100
    )
    error_message = "The capacity provider must manage scaling, termination protection and draining."
  }

  assert {
    condition     = aws_ecs_cluster_capacity_providers.this.capacity_providers == toset([aws_ecs_capacity_provider.this.name]) && one(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy).capacity_provider == aws_ecs_capacity_provider.this.name
    error_message = "The capacity provider must be the cluster default."
  }

  assert {
    condition     = toset(aws_autoscaling_group.this.vpc_zone_identifier) == toset(var.subnet_ids)
    error_message = "Instances must launch in the given subnets."
  }

  assert {
    condition     = aws_autoscaling_group.this.ignore_failed_scaling_activities
    error_message = "The ASG must keep waiting through failed launches (IAM propagation)."
  }

  assert {
    condition     = aws_iam_role.instance.permissions_boundary == var.permissions_boundary_arn && aws_iam_role.instance.path == "/workload/"
    error_message = "The instance role must carry the boundary and live under /workload/."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.instance) == 2
    error_message = "The instance role must have only the ECS and SSM managed policies."
  }

  assert {
    condition     = length(aws_security_group.instance.ingress) == 0
    error_message = "The instance security group must have no inbound rules."
  }

  assert {
    condition     = aws_launch_template.this.tag_specifications[0].tags["Project"] == "mdb" && aws_launch_template.this.tag_specifications[0].tags["Name"] == "mdb-test-ecs"
    error_message = "Instances must carry the provider's default tags and a Name."
  }

  assert {
    condition     = one([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"]) == "disabled"
    error_message = "Container Insights must be off."
  }
}

run "scale_to_zero_allowed" {
  variables {
    min_size = 0
  }

  assert {
    condition     = aws_autoscaling_group.this.min_size == 0 && aws_autoscaling_group.this.max_size == 2
    error_message = "min_size 0 must let ECS scale the ASG to zero."
  }
}

run "rejects_max_below_min" {
  command = plan

  variables {
    min_size = 3
    max_size = 2
  }

  expect_failures = [var.max_size]
}

run "rejects_bad_ami" {
  command = plan

  variables {
    ami_id = "ubuntu-latest"
  }

  expect_failures = [var.ami_id]
}

run "rejects_no_subnets" {
  command = plan

  variables {
    subnet_ids = []
  }

  expect_failures = [var.subnet_ids]
}
