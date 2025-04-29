# --- ECS Task Execution Role ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Rekognition Task Role and Policy ---
data "aws_iam_policy_document" "rekognition_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rekognition_task_role" {
  name               = "${var.project_name}-${var.environment}-rekognition-task-role"
  assume_role_policy = data.aws_iam_policy_document.rekognition_task_assume_role.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "rekognition_task_policy" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-${var.environment}-rekognition:*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["rekognition:DetectText"]
    resources = ["*"] # Rekognition actions often require "*"
    effect    = "Allow"
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_bucket_arn}/*"] # Access to objects in the bucket
    effect    = "Allow"
  }
  # NEW: Allow putting results into the designated prefix
  statement {
    sid    = "S3PutRekognitionResults"
    actions = ["s3:PutObject"]
    resources = ["${var.s3_bucket_arn}/rekognition-results/*"] 
    effect = "Allow"
  }
  # Add DynamoDB permissions if needed by container
  dynamic "statement" {
    for_each = var.dynamodb_table_arn != null ? [1] : []
    content {
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"] # Adjust as needed
      resources = [var.dynamodb_table_arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_policy" "rekognition_task_policy" {
  name        = "${var.project_name}-${var.environment}-rekognition-task-policy"
  description = "IAM policy for Rekognition ECS task"
  policy      = data.aws_iam_policy_document.rekognition_task_policy.json
}

resource "aws_iam_role_policy_attachment" "rekognition_task_policy_attachment" {
  role       = aws_iam_role.rekognition_task_role.name
  policy_arn = aws_iam_policy.rekognition_task_policy.arn
}

# --- Transcribe Task Role and Policy ---
data "aws_iam_policy_document" "transcribe_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "transcribe_task_role" {
  name               = "${var.project_name}-${var.environment}-transcribe-task-role"
  assume_role_policy = data.aws_iam_policy_document.transcribe_task_assume_role.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "transcribe_task_policy" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-${var.environment}-transcribe:*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["transcribe:StartTranscriptionJob", "transcribe:GetTranscriptionJob"]
    resources = ["*"] # Transcribe actions often require "*"
    effect    = "Allow"
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.s3_bucket_arn}/*"] 
    effect    = "Allow"
  }
  # CLARIFY: Existing PutObject is for the whole bucket. 
  # Keep it for now, or restrict further if needed, e.g.:
  # statement {
  #   sid = "S3GetObjectInputAudio"
  #   actions = ["s3:GetObject"]
  #   resources = ["${var.s3_bucket_arn}/temp-audio/*"]
  #   effect = "Allow"
  # }
  # statement {
  #   sid = "S3PutTranscribeResults"
  #   actions = ["s3:PutObject"]
  #   resources = ["${var.s3_bucket_arn}/transcribe-results/*"]
  #   effect = "Allow"
  # }
  # Add DynamoDB permissions if needed by container
  dynamic "statement" {
    for_each = var.dynamodb_table_arn != null ? [1] : []
    content {
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"] # Adjust as needed
      resources = [var.dynamodb_table_arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_policy" "transcribe_task_policy" {
  name        = "${var.project_name}-${var.environment}-transcribe-task-policy"
  description = "IAM policy for Transcribe ECS task"
  policy      = data.aws_iam_policy_document.transcribe_task_policy.json
}

resource "aws_iam_role_policy_attachment" "transcribe_task_policy_attachment" {
  role       = aws_iam_role.transcribe_task_role.name
  policy_arn = aws_iam_policy.transcribe_task_policy.arn
}

data "aws_caller_identity" "current" {} 