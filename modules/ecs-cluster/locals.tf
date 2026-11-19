# Instances launched by the ASG don't get the provider's default_tags, so pass them on explicitly.
data "aws_default_tags" "current" {}

locals {
  instance_tags = merge(data.aws_default_tags.current.tags, var.tags, { Name = "${var.name}-ecs" })

  user_data = <<-EOT
    #!/bin/bash
    cat <<'CFG' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${var.name}
    ECS_AWSVPC_BLOCK_IMDS=true
    CFG
  EOT
}
