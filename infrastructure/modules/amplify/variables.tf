# infrastructure/modules/amplify/variables.tf

variable "app_name" {
  description = "Name for the Amplify app"
  type        = string
  default     = "brevitycloud-landing-page"
}

variable "repo_url" {
  description = "URL of the GitHub repository (e.g., https://github.com/your-user/your-repo)"
  type        = string
}

variable "github_pat_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the GitHub Personal Access Token (PAT)"
  type        = string
}

variable "branch_name" {
  description = "Branch to deploy"
  type        = string
  default     = "hemanth"
}

variable "user_tag" {
  description = "User tag for resource identification"
  type        = string
  default     = "default-user"
} 