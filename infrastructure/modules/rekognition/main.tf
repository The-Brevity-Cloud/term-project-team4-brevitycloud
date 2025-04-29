data "aws_caller_identity" "current" {}

# Rekognition Lambda Integration (Points to Invoker Lambda)
resource "aws_apigatewayv2_integration" "rekognition_lambda_integration" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  # Use the INVOKER Lambda ARN passed as input
  integration_uri    = var.invoke_rekognition_lambda_arn 
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Rekognition Route
resource "aws_apigatewayv2_route" "rekognition_route" {
  api_id    = var.api_gateway_id
  route_key = "POST /rekognition"
  target    = "integrations/${aws_apigatewayv2_integration.rekognition_lambda_integration.id}"
}

# Rekognition Lambda Permission (For Invoker Lambda)
resource "aws_lambda_permission" "rekognition_invoker_permission" {
  statement_id  = "AllowAPIGatewayInvokeRekognitionInvoker"
  action        = "lambda:InvokeFunction"
  function_name = var.invoke_rekognition_lambda_name
  principal     = "apigateway.amazonaws.com"
  # Construct Source ARN from API GW execution ARN and the specific route key
  source_arn    = "${var.api_gateway_execution_arn}/*/${aws_apigatewayv2_route.rekognition_route.route_key}"
} 