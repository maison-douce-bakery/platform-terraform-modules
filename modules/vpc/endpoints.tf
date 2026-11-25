data "aws_region" "current" {}

# Free. S3 traffic from public and private subnets (ECR image layers, logs) skips the internet path and NAT per-GB charges.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], values(aws_route_table.private)[*].id)

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
