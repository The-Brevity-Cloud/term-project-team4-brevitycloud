output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.prod.invoke_url}/summarize"
  description = "API Gateway endpoint URL for the Lambda function"
}