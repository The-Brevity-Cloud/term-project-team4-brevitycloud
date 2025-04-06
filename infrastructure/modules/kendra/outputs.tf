output "kendra_index_id" {
  description = "ID of the Kendra index"
  value       = aws_kendra_index.webpage_index.id
} 

output "kendra_role_arn" {
  description = "ARN of the IAM role for Kendra"
  value       = aws_iam_role.kendra_role.arn
}