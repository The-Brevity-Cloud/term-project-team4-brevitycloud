# infrastructure/modules/amplify/main.tf

data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = var.github_pat_secret_name
}

resource "aws_amplify_app" "app" {
  name                       = "${var.app_name}-${var.user_tag}" 
  repository                 = var.repo_url
  access_token               = data.aws_secretsmanager_secret_version.github_pat.secret_string
  platform                   = "WEB" # Static web hosting
  # Disable auto-build features
  enable_branch_auto_build   = false 
  enable_branch_auto_deletion = false 
  
  # Simple build spec for static content in landing-page directory
  build_spec                 = <<-EOT
    version: 1.0
    frontend:
      phases:
        preBuild:
          commands: []
        build:
          commands: []
      artifacts:
        baseDirectory: /landing-page # IMPORTANT: Point to landing-page dir
        files:
          - '**/*'
      cache:
        paths: []
  EOT

  tags = {
    Project   = "BrevityCloud-Landing"
    ManagedBy = "Terraform"
    User      = var.user_tag
  }
}

resource "aws_amplify_branch" "branch" {
  app_id      = aws_amplify_app.app.id
  branch_name = var.branch_name
  stage       = "PRODUCTION" # Or DEVELOPMENT

  # Ensure auto-build is off for this specific branch too
  enable_auto_build = false 

  tags = {
    Project   = "BrevityCloud-Landing"
    ManagedBy = "Terraform"
    User      = var.user_tag
  }
} 