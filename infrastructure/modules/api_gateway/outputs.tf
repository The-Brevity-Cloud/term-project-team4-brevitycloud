output "api_endpoint" {
  value = aws_apigatewayv2_stage.prod.invoke_url
  description = "API Gateway endpoint URL"
}
