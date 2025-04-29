# infrastructure/modules/amplify/outputs.tf

output "app_id" {
  description = "The ID of the Amplify App"
  value       = aws_amplify_app.app.id
}

output "app_arn" {
  description = "The ARN of the Amplify App"
  value       = aws_amplify_app.app.arn
}

output "default_domain" {
  description = "The default domain for the Amplify App (usually tied to the specified branch)"
  value       = aws_amplify_app.app.default_domain
} 