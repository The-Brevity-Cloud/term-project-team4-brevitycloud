variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project used as prefix for resources"
  type        = string
  default     = "brevity-cloud"
}

variable "user" {
  description = "Identifier for the team member deploying (used for resource naming/tagging)"
  type        = string
  # No default - must be provided by workflow
}

variable "github_repository_url" {
  description = "URL of the GitHub repository for Amplify connection (e.g., https://github.com/your-user/your-repo)"
  type        = string
  default     = "https://github.com/The-Brevity-Cloud/term-project-team4-brevitycloud" # Defaulted to your repo
}

variable "github_pat_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the GitHub PAT for Amplify"
  type        = string
  default     = "Github-PAT" # Use the name confirmed earlier
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod), typically matches user for this project."
  type        = string
  default     = "dev" # Default if 'user' variable isn't used for environment directly
}

# --- Container Image URIs (Passed from CI/CD) ---
variable "rekognition_image_uri" {
  description = "ECR image URI for the Rekognition service container (including tag)"
  type        = string
  default     = "placeholder" # Add default value
}

variable "transcribe_image_uri" {
  description = "ECR image URI for the Transcribe service container (including tag)"
  type        = string
  default     = "placeholder" # Add default value
}

# --- NEW: Branch for Landing Page Source ---
variable "landing_page_source_branch" {
  description = "The branch in the GitHub repository that contains the landing page source code."
  type        = string
  # No default - should be provided via tfvars
}