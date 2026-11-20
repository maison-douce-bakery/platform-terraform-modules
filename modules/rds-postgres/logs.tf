# Created before the instance; otherwise RDS creates them with no retention.
resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(local.log_exports)

  name              = "/aws/rds/instance/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
