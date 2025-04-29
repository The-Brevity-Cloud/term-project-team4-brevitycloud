resource "aws_ecr_repository" "repo" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name        = "${var.repository_name}-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Optional: Lifecycle policy to clean up old images
# resource "aws_ecr_lifecycle_policy" "default" {
#   repository = aws_ecr_repository.repo.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1,
#         description  = "Keep only last 10 images",
#         selection = {
#           tagStatus     = "any",
#           countType     = "imageCountMoreThan",
#           countNumber   = 10
#         },
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# } 