output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "capacity_provider_name" {
  description = "Capacity provider that services use (also the cluster default)."
  value       = aws_ecs_capacity_provider.this.name
}
