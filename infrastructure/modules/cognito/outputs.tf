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

output "user_pool_issuer_url" {
  description = "Issuer URL for the Cognito User Pool (used for JWT validation)"
  # Issuer URL format: https://cognito-idp.{region}.amazonaws.com/{userPoolId}
  # Need region info - assuming it can be derived or is available via a data source/variable.
  # For now, construct it manually assuming aws_region is available or hardcoded.
  # If not, this needs adjustment based on how region is determined.
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
