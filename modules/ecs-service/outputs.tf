output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "security_group_id" {
  description = "Security group of the tasks. Add it to the ingress of the resources they call, such as RDS."
  value       = aws_security_group.this.id
}

output "task_role_arn" {
  description = "ARN of the application's task role."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "CloudWatch log group of the container."
  value       = aws_cloudwatch_log_group.this.name
}
