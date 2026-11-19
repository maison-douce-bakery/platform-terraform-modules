# Instance role only runs the ECS and SSM agents. App permissions go in task roles.
# Path is outside /platform/, which the boundary protects.
resource "aws_iam_role" "instance" {
  name                 = "${var.name}-ecs-instance"
  path                 = "/workload/"
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "instance" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.instance.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-ecs-instance"
  path = "/workload/"
  role = aws_iam_role.instance.name

  tags = var.tags
}
