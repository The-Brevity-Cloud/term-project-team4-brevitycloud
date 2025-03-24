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