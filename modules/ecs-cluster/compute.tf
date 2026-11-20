# No inbound rules: access is through SSM, and nothing listens publicly.
resource "aws_security_group" "instance" {
  name        = "${var.name}-ecs-instance"
  description = "ECS container instances. No inbound."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-ecs-instance" })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.instance.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Egress to ECS, ECR, SSM and the internet through the NAT"
}

resource "aws_launch_template" "this" {
  name          = "${var.name}-ecs"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  vpc_security_group_ids = [aws_security_group.instance.id]

  # IMDSv2 only. Hop limit 1 keeps bridge-mode containers off the instance role's credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = false
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.instance_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.instance_tags
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name}-ecs"
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids
  health_check_type   = "EC2"

  # Required by managed termination protection: ECS decides which instances may be scaled in.
  protect_from_scale_in = true

  # A new instance profile can be rejected for a few seconds after creation. Keep waiting while the
  # ASG retries instead of failing the apply and leaving the ASG tainted.
  ignore_failed_scaling_activities = true

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # The ASG takes tag blocks, not the provider's default_tags. Instances get theirs from the launch template.
  dynamic "tag" {
    for_each = local.instance_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  # ECS adds this tag when it manages the ASG; declaring it avoids a diff.
  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  # Instances register with the cluster on boot, so it must exist first.
  depends_on = [aws_ecs_cluster.this]

  # ECS managed scaling owns the instance count.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
