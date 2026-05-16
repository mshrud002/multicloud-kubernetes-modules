output "karpenter_role_arn" {
  description = "IAM role ARN for Karpenter IRSA"
  value       = aws_iam_role.karpenter_irsa.arn
}

output "node_role_arn" {
  description = "IAM role ARN for Karpenter managed nodes"
  value       = local.node_role
}

output "node_role_name" {
  description = "IAM role name for Karpenter managed nodes"
  value       = var.node_role_arn == null ? aws_iam_role.karpenter_node[0].name : split("/", var.node_role_arn)[1]
}

output "interruption_queue_url" {
  description = "URL of the SQS queue for interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "interruption_queue_arn" {
  description = "ARN of the SQS queue for interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}
