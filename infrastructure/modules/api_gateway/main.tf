# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    expose_headers = ["*"]
    max_age = 300
  }
}

# IAM role for API Gateway CloudWatch logs
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${var.project_name}-api-gw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# API Gateway account settings to enable CloudWatch logs
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
  reset_on_delete = true
}

# Attaching CloudWatch logs policy to the role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Create a log group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-api/access-logs"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "prod"
  auto_deploy = true

  # Add access logging settings
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      errorMessage   = "$context.error.message"
    })
  }
}

# Summarize Lambda Integration
resource "aws_apigatewayv2_integration" "summarize_lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.summarize_lambda_invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Auth Lambda Integration
resource "aws_apigatewayv2_integration" "auth_lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.auth_lambda_invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Summarize Route
resource "aws_apigatewayv2_route" "summarize_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /summarize"
  target    = "integrations/${aws_apigatewayv2_integration.summarize_lambda_integration.id}"
}

# Auth Routes
resource "aws_apigatewayv2_route" "auth_routes" {
  for_each = toset([
    "POST /auth/register",
    "POST /auth/login",
    "POST /auth/verify",
    "POST /auth/resend-code"
  ])

  api_id    = aws_apigatewayv2_api.api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda_integration.id}"
}

# History Route (uses summarize lambda integration)
resource "aws_apigatewayv2_route" "history_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /history"
  target    = "integrations/${aws_apigatewayv2_integration.summarize_lambda_integration.id}"
  # Add authorization if needed (e.g., JWT authorizer)
  # authorization_type = "JWT"
  # authorizer_id      = aws_apigatewayv2_authorizer.jwt_authorizer.id 
}

# Summarize Lambda Permission
resource "aws_lambda_permission" "summarize_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.summarize_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Auth Lambda Permission
resource "aws_lambda_permission" "auth_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# --- Get Result Integration & Route ---
resource "aws_apigatewayv2_integration" "get_result_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.get_result_lambda_invoke_arn
  integration_method = "POST" # Lambda proxy integration always uses POST
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_result_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /results/{jobId}" # Use path parameter for jobId
  target    = "integrations/${aws_apigatewayv2_integration.get_result_integration.id}"
}

# Permission for API Gateway to invoke Get Result Lambda
resource "aws_lambda_permission" "apigw_get_result_invoke" {
  statement_id  = "AllowAPIGatewayInvokeGetResult"
  action        = "lambda:InvokeFunction"
  function_name = var.get_result_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/${aws_apigatewayv2_route.get_result_route.route_key}"
}
