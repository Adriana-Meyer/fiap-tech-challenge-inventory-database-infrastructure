output "db_endpoint" {
  description = "host:port of the instance. The workflow turns it into the service's JDBC URL."
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_username" {
  value = aws_db_instance.main.username
}

output "db_password" {
  description = "Never printed: terraform-apply.yml pipes it straight into the service repository's secrets."
  value       = random_password.db_master.result
  sensitive   = true
}
