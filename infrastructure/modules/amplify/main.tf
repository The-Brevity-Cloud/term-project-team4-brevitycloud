# infrastructure/modules/amplify/main.tf

data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = var.github_pat_secret_name
}

resource "aws_amplify_app" "app" {
  name                       = "${var.app_name}-${var.user_tag}" 
  repository                 = var.repo_url
  access_token               = data.aws_secretsmanager_secret_version.github_pat.secret_string
  platform                   = "WEB" # Static web hosting
  # Automatically build branches
  enable_branch_auto_build   = true 
  # Optional: Automatically delete Amplify branches when Git branches are deleted
  enable_branch_auto_deletion = true 
  
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

  # Enable auto-build on push to this branch
  # Changes pushed to landing-page/ on this branch will trigger deploy
  enable_auto_build = true 

  tags = {
    Project   = "BrevityCloud-Landing"
    ManagedBy = "Terraform"
    User      = var.user_tag
  }
}

# Branch configuration (Now potentially managed by auto-build)
# We might still want to explicitly define the main branch if needed
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.app.id
  branch_name = var.branch_name # Use the variable, likely points to 'amplify' branch based on main.tf
  # Enable basic auth if needed, etc.
  # enable_auto_build = true # Now handled at the app level
} 