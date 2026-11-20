output "address" {
  description = "Hostname of the DB instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group of the DB instance. Consumers add their 5432 ingress rules to it."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN of the master user credentials, managed by RDS."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
