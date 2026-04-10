output "instance_id" {
  description = "EC2 instance ID of the daemon"
  value       = aws_instance.daemon.id
}

output "private_ip" {
  description = "Private IP address of the daemon EC2 instance"
  value       = aws_instance.daemon.private_ip
}

output "security_group_id" {
  description = "ID of the daemon security group"
  value       = aws_security_group.daemon.id
}

output "iam_role_arn" {
  description = "ARN of the daemon IAM role"
  value       = aws_iam_role.daemon.arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret storing the daemon keypair"
  value       = aws_secretsmanager_secret.daemon_keypair.arn
}
