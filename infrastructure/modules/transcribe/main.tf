data "aws_caller_identity" "current" {}

# Policy attachment for Transcribe access
resource "aws_iam_role_policy_attachment" "lambda_transcribe" {
  role       = var.lambda_role_name
  policy_arn = var.transcribe_policy_arn
}

# Note: S3 access policy is assumed to be attached to the shared role in the main lambda module
# If more specific S3 permissions are needed ONLY for this lambda, define them here
# resource "aws_iam_role_policy_attachment" "lambda_transcribe_s3" {
#   role       = var.lambda_role_arn
#   policy_arn = var.s3_policy_arn 
# }

# Lambda function for Transcribe
resource "aws_lambda_function" "transcribe_lambda" {
  filename         = var.transcribe_lambda_zip_path
  function_name    = "${var.project_name}-transcribe"
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lambda_role_name}"
  handler          = "transcribe.lambda_handler" # Assuming handler in transcribe.py
  runtime          = "python3.9"
  timeout          = 90 # Increased timeout for potential S3 upload + Transcribe job
  memory_size      = 256

  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      # Add other env vars if needed, e.g., output bucket for Transcribe jobs
    }
  }
}

# Transcribe Lambda Integration
resource "aws_apigatewayv2_integration" "transcribe_lambda_integration" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.transcribe_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
  # Consider increasing timeout if Lambda processing takes longer
  # timeout_milliseconds = 29000 
}

# Transcribe Route
resource "aws_apigatewayv2_route" "transcribe_route" {
  api_id    = var.api_gateway_id
  route_key = "POST /transcribe"
  target    = "integrations/${aws_apigatewayv2_integration.transcribe_lambda_integration.id}"
}

# Transcribe Lambda Permission
resource "aws_lambda_permission" "transcribe_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvokeTranscribe"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcribe_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
} 