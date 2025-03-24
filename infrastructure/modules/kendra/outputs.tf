output "kendra_index_id" {
  description = "ID of the Kendra index"
  value       = aws_kendra_index.webpage_index.id
} 