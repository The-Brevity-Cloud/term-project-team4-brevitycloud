# IAM role for Kendra
resource "aws_iam_role" "kendra_role" {
  name = "${var.project_name}-kendra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "kendra.amazonaws.com"
        }
      }
    ]
  })
}

# Adding required policies for Kendra role
resource "aws_iam_role_policy_attachment" "kendra_cloudwatch" {
  role       = aws_iam_role.kendra_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Creating Kendra index
resource "aws_kendra_index" "webpage_index" {
  name        = "${var.project_name}-index"
  description = "Index for webpage content to be summarized"
  edition     = "DEVELOPER_EDITION"
  role_arn    = aws_iam_role.kendra_role.arn
}

resource "aws_iam_role_policy" "kendra_s3_access" {
  name = "${var.project_name}-kendra-s3-access"
  role = aws_iam_role.kendra_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-webpage-content",
          "arn:aws:s3:::${var.project_name}-webpage-content/*"
        ]
      }
    ]
  })
}
