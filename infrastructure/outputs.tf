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

# Add Amplify Landing Page URL Output
output "amplify_landing_page_url" {
  description = "URL for the static landing page hosted on Amplify"
  # Use the default_domain output from the amplify module instance
  value       = "https://${module.amplify_landing_page.default_domain}"
}

output "amplify_app_id" {
  description = "Amplify App ID"
  value       = module.amplify_landing_page.app_id # Assuming your amplify module is named 'amplify_landing_page'
}