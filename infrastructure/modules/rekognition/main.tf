data "aws_caller_identity" "current" {}

# Policy attachment for Rekognition access
# Note: Attaching to the role NAME passed in
resource "aws_iam_role_policy_attachment" "lambda_rekognition" {
  role       = var.lambda_role_name # Use the role NAME
  policy_arn = var.rekognition_policy_arn
}

# Lambda function for Rekognition
resource "aws_lambda_function" "rekognition_lambda" {
  filename         = var.rekognition_lambda_zip_path
  function_name    = "${var.project_name}-rekognition"
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lambda_role_name}" # Construct ARN here if needed, or pass full ARN separately for the lambda function resource
  handler          = "rekognition.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
}

# Rekognition Lambda Integration
resource "aws_apigatewayv2_integration" "rekognition_lambda_integration" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.rekognition_lambda.invoke_arn # Use the invoke ARN from the lambda created here
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Rekognition Route
resource "aws_apigatewayv2_route" "rekognition_route" {
  api_id    = var.api_gateway_id
  route_key = "POST /rekognition"
  target    = "integrations/${aws_apigatewayv2_integration.rekognition_lambda_integration.id}"
}

# Rekognition Lambda Permission
resource "aws_lambda_permission" "rekognition_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvokeRekognition"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rekognition_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*" # Use the execution ARN passed as input
} 