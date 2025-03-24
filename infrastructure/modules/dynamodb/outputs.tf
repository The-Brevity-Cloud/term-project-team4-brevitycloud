output "dynamodb_table_arn" {
  value = aws_dynamodb_table.user_data.arn
  description = "ARN of the DynamoDB table"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.user_data.name
  description = "Name of the DynamoDB table"
}
