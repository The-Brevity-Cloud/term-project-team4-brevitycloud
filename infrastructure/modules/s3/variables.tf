variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "kendra_index_id" {
  description = "ID of the Kendra index"
  type        = string
}

variable "kendra_role_arn" {
  description = "ARN of the IAM role for Kendra"
  type        = string
}