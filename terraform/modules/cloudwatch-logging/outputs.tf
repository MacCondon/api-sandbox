output "log_group_name" {
  description = "Name of the CloudWatch log group for container logs"
  value       = aws_cloudwatch_log_group.containers.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for container logs"
  value       = aws_cloudwatch_log_group.containers.arn
}

output "fluent_bit_role_arn" {
  description = "ARN of the IAM role used by Fluent Bit"
  value       = aws_iam_role.fluent_bit.arn
}
