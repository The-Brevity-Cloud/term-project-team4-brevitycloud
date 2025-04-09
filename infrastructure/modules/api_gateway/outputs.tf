output "api_endpoint" {
  value = aws_apigatewayv2_stage.prod.invoke_url
  description = "API Gateway endpoint URL"
}

output "api_gateway_id" {
  value       = aws_apigatewayv2_api.api.id
  description = "ID of the HTTP API Gateway"
}

output "api_gateway_execution_arn" {
  value       = aws_apigatewayv2_api.api.execution_arn
  description = "Execution ARN of the HTTP API Gateway"
}
