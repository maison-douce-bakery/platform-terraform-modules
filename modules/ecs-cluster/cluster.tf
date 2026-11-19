resource "aws_ecs_cluster" "this" {
  name = var.name

  # Off in dev: Container Insights is billed per metric.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}
