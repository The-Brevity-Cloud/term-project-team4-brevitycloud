resource "aws_s3_bucket" "webpage_content" {
  bucket = "${var.project_name}-webpage-content"
  
  force_destroy = true
  
  tags = {
    Name = "${var.project_name}-webpage-content"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.webpage_content.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "webpage_content_versioning" {
  bucket = aws_s3_bucket.webpage_content.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "kendra_access" {
  bucket = aws_s3_bucket.webpage_content.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "kendra.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.webpage_content.arn,
          "${aws_s3_bucket.webpage_content.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount": data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn": "arn:aws:kendra:${var.aws_region}:${data.aws_caller_identity.current.account_id}:index/${var.kendra_index_id}"
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "shared_folder" {
  bucket = aws_s3_bucket.webpage_content.id
  key    = "shared/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "websites_folder" {
  bucket = aws_s3_bucket.webpage_content.id
  key    = "shared/websites/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "metadata_folder" {
  bucket = aws_s3_bucket.webpage_content.id
  key    = "shared/metadata/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "private_folder" {
  bucket = aws_s3_bucket.webpage_content.id
  key    = "private/"
  content_type = "application/x-directory"
}

resource "aws_kendra_data_source" "s3_data_source" {
  index_id = var.kendra_index_id
  name     = "webpage-content-s3"
  type     = "S3"
  
  role_arn = var.kendra_role_arn
  
  configuration {
    s3_configuration {
      bucket_name = aws_s3_bucket.webpage_content.id
      inclusion_prefixes = ["shared/websites/"]
    }
  }
}

data "aws_caller_identity" "current" {}