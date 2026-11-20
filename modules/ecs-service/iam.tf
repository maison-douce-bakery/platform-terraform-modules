# Used by ECS to pull the image, write logs and read the secrets at task start.
resource "aws_iam_role" "execution" {
  name                 = "${var.name}-execution"
  path                 = "/workload/"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "read-secrets"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{ Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = local.secret_arns }],
      length(var.secrets_kms_key_arns) > 0 ? [{ Effect = "Allow", Action = "kms:Decrypt", Resource = var.secrets_kms_key_arns }] : [],
    )
  })
}

# Used by the application itself. No permissions unless the caller grants some.
resource "aws_iam_role" "task" {
  name                 = "${var.name}-task"
  path                 = "/workload/"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = local.assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy" "task" {
  count = var.task_role_policy_json == null ? 0 : 1

  name   = "app"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}
