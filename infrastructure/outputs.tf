output "api_endpoint" {
  value       = module.api_gateway.api_endpoint
  description = "API Gateway endpoint URL"
}

output "cognito_user_pool_client_id" {
  value       = module.cognito.cognito_client_id
  description = "Cognito User Pool Client ID"
}

output "cognito_user_pool_id" {
  value       = module.cognito.cognito_user_pool_id
  description = "Cognito User Pool ID"
}