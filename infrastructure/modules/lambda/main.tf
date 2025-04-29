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

# --- Create Separate IAM Role for Invoker Lambdas --- 
resource "aws_iam_role" "invoke_lambda_role" {
  name = "${var.project_name}-invoke-lambda-role"

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

# Policy attachment for Lambda basic execution for Invoker Role
resource "aws_iam_role_policy_attachment" "invoke_lambda_basic" {
  role       = aws_iam_role.invoke_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy document for Invoker Lambdas (ECS RunTask, PassRole, S3 Put Temp)
data "aws_iam_policy_document" "invoke_lambda_policy_doc" {
  statement { # S3 Permissions for Temp Audio Upload (Transcribe Invoker)
      sid = "S3PutTempAudio"
      actions = ["s3:PutObject"]
      # Allow putting into the specific temp prefix
      resources = ["${var.s3_bucket_arn}/temp-audio/*"]
      effect = "Allow"
  }
  statement { # ECS RunTask Permissions
    sid    = "ECSRunTaskPermissions"
    effect = "Allow"
    actions = ["ecs:RunTask"]
    # Allow running both task definitions
    resources = [
      var.rekognition_task_def_arn,
      var.transcribe_task_def_arn
    ]
  }
  statement { # ECS PassRole Permissions
    sid    = "ECSPassRolePermissions"
    effect = "Allow"
    actions = ["iam:PassRole"]
    # Allow passing the specific task roles and execution role
    resources = [
      var.ecs_rekognition_task_role_arn,
      var.ecs_transcribe_task_role_arn,
      var.ecs_task_execution_role_arn 
    ]
  }
}

# Create the IAM policy for Invoker Lambdas
resource "aws_iam_policy" "invoke_lambda_policy" {
  name   = "${var.project_name}-invoke-lambda-policy"
  policy = data.aws_iam_policy_document.invoke_lambda_policy_doc.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Attach the custom policy to the Invoker Role
resource "aws_iam_role_policy_attachment" "invoke_lambda_policy_attachment" {
  role       = aws_iam_role.invoke_lambda_role.name
  policy_arn = aws_iam_policy.invoke_lambda_policy.arn
}

# --- Rekognition Invoker Lambda ---
resource "aws_lambda_function" "invoke_rekognition" {
  function_name    = "${var.project_name}-${var.environment}-invoke-rekognition" # Added environment 
  handler          = "invoke_rekognition.lambda_handler" 
  runtime          = "python3.9"
  role             = aws_iam_role.invoke_lambda_role.arn # Use the new dedicated role
  filename         = var.rekognition_lambda_zip_path
  source_code_hash = filebase64sha256(var.rekognition_lambda_zip_path)
  timeout          = 30 # Adjust timeout as needed

  environment {
    variables = {
      ECS_CLUSTER_ARN            = var.ecs_cluster_arn
      REKOGNITION_TASK_DEF_ARN = var.rekognition_task_def_arn
      PRIVATE_SUBNET_IDS       = join(",", var.private_subnet_ids) # Pass as comma-separated string
      TASK_SECURITY_GROUP_ID   = var.task_security_group_id
      # Add any other env vars needed by the invoker
    }
  }

  tags = {
    Name        = "${var.project_name}-invoke-rekognition-lambda"
    Project     = var.project_name
    Environment = var.environment # Assuming environment var exists
  }
}

# --- Transcribe Invoker Lambda ---
resource "aws_lambda_function" "invoke_transcribe" {
  function_name    = "${var.project_name}-${var.environment}-invoke-transcribe" # Added environment
  handler          = "invoke_transcribe.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.invoke_lambda_role.arn # Use the new dedicated role
  filename         = var.transcribe_lambda_zip_path
  source_code_hash = filebase64sha256(var.transcribe_lambda_zip_path)
  timeout          = 30 # Adjust timeout as needed

  environment {
    variables = {
      ECS_CLUSTER_ARN           = var.ecs_cluster_arn
      TRANSCRIBE_TASK_DEF_ARN = var.transcribe_task_def_arn
      PRIVATE_SUBNET_IDS      = join(",", var.private_subnet_ids)
      TASK_SECURITY_GROUP_ID  = var.task_security_group_id
      # Add any other env vars needed by the invoker
    }
  }

  tags = {
    Name        = "${var.project_name}-invoke-transcribe-lambda"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Get Result Lambda ---
resource "aws_lambda_function" "get_result" {
  function_name    = "${var.project_name}-${var.environment}-get-result" # Added environment
  handler          = "get_result.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_role.arn # Use the ORIGINAL role
  filename         = var.get_result_lambda_zip_path
  source_code_hash = filebase64sha256(var.get_result_lambda_zip_path)
  timeout          = 15 

  environment {
    variables = {
      S3_BUCKET          = var.s3_bucket_name 
      REKOGNITION_PREFIX = "rekognition-results" # Standardized prefix
      TRANSCRIBE_PREFIX  = "transcribe-results"  # Standardized prefix
    }
  }

  tags = {
    Name        = "${var.project_name}-get-result-lambda"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Update main lambda execution role policy ---
# Combine existing policies (DynamoDB/Cognito from lambda_policy, S3 from lambda_s3_access)
# with new ECS permissions into a single policy document.
data "aws_iam_policy_document" "lambda_combined_policy_doc" {
  # Source the existing inline policy statements JSON directly
  # Reconstruct the policy document content here instead of sourcing non-existent resources
  statement { # DynamoDB Permissions
    sid    = "DynamoDBPermissions"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [var.dynamodb_table_arn]
  }
  statement { # Cognito Permissions
    sid    = "CognitoPermissions"
    effect = "Allow"
    actions = [
      "cognito-idp:AdminInitiateAuth",
      "cognito-idp:AdminCreateUser"
    ]
    resources = [var.cognito_user_pool_arn]
  }
   statement { # S3 Permissions (General Bucket Access + Results Get)
    sid = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:HeadObject"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*" # General access
    ]
  }
  statement { # Add S3 GetObject for result paths (Keep for get_result lambda)
    sid    = "S3GetResults"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${var.s3_bucket_arn}/rekognition-results/*",
      "${var.s3_bucket_arn}/transcribe-results/*"
    ]
  }
}

# Create the new combined IAM policy (Now only for summarize/auth/get_result)
resource "aws_iam_policy" "lambda_combined_policy" {
  name   = "${var.project_name}-lambda-combined-policy"
  policy = data.aws_iam_policy_document.lambda_combined_policy_doc.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Manage Policy Attachments ---
# Attach the combined policy to the ORIGINAL lambda role
resource "aws_iam_role_policy_attachment" "lambda_combined_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_combined_policy.arn
}

# Removed old policy/attachment resources