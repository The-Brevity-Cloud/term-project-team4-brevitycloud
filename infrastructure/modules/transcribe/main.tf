data "aws_caller_identity" "current" {}

# Note: S3 access policy is assumed to be attached to the shared role in the main lambda module
# If more specific S3 permissions are needed ONLY for this lambda, define them here
# resource "aws_iam_role_policy_attachment" "lambda_transcribe_s3" {
#   role       = var.lambda_role_arn
#   policy_arn = var.s3_policy_arn 
# }

# Transcribe Lambda Integration (Points to Invoker Lambda)
resource "aws_apigatewayv2_integration" "transcribe_lambda_integration" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  # Use the INVOKER Lambda ARN passed as input
  integration_uri    = var.invoke_transcribe_lambda_arn 
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Transcribe Route
resource "aws_apigatewayv2_route" "transcribe_route" {
  api_id    = var.api_gateway_id
  route_key = "POST /transcribe"
  target    = "integrations/${aws_apigatewayv2_integration.transcribe_lambda_integration.id}"
}

# Transcribe Lambda Permission (For Invoker Lambda)
resource "aws_lambda_permission" "transcribe_invoker_permission" {
  statement_id  = "AllowAPIGatewayInvokeTranscribeInvoker"
  action        = "lambda:InvokeFunction"
  function_name = var.invoke_transcribe_lambda_name
  principal     = "apigateway.amazonaws.com"
  # Construct Source ARN from API GW execution ARN and the specific route key
  source_arn    = "${var.api_gateway_execution_arn}/*/${aws_apigatewayv2_route.transcribe_route.route_key}"
} 