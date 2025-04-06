# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy attachment for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Bedrock access
resource "aws_iam_role_policy_attachment" "lambda_bedrock" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

# Add Kendra permissions to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_kendra" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKendraFullAccess"
}

# Lambda IAM role to include DynamoDB and Cognito permissions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminCreateUser"
        ]
        Resource = var.cognito_user_pool_arn
      }
    ]
  })
}

# Lambda function for summarization
resource "aws_lambda_function" "summarize_lambda" {
  function_name = "${var.project_name}-summarize"
  role          = aws_iam_role.lambda_role.arn
  handler       = "summarize.lambda_handler"
  runtime       = "python3.9"
  filename      = var.lambda_zip_path
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      KENDRA_INDEX_ID  = var.kendra_index_id
      USER_TABLE_NAME  = var.dynamodb_table_name
      COGNITO_CLIENT_ID = var.cognito_client_id
      S3_BUCKET_NAME    = var.s3_bucket_name
    }
  }
}

# Lambda function for authentication
resource "aws_lambda_function" "auth_lambda" {
  filename         = var.auth_lambda_zip_path
  function_name    = "${var.project_name}-auth"
  role             = aws_iam_role.lambda_role.arn
  handler          = "auth.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      USER_TABLE_NAME   = var.dynamodb_table_name
      COGNITO_CLIENT_ID = var.cognito_client_id
    }
  }
}

# Adding S3 access permissions here, as adding it inside the s3 modules, resulted in a circular dependency error
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.project_name}-lambda-s3-access"
  description = "Allow Lambda to access S3 bucket for webpage content"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:HeadObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Attach S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}