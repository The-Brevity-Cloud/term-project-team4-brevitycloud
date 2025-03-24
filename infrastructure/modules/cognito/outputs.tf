output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
  description = "ID of the Cognito user pool"
}

output "cognito_user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
  description = "ARN of the Cognito user pool"
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.client.id
  description = "ID of the Cognito user pool client"
}
