output "iam_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for the AWS Load Balancer Controller"
  value       = aws_iam_policy.lb_controller.arn
}
