variable "project_name" {
  description = "Name of the project used as prefix for resources"
  type        = string
}

variable "summarize_lambda_invoke_arn" {
  description = "Invoke ARN of the summarize Lambda function"
  type        = string
}

variable "auth_lambda_invoke_arn" {
  description = "Invoke ARN of the auth Lambda function"
  type        = string
}

variable "summarize_lambda_name" {
  description = "Name of the summarize Lambda function"
  type        = string
}

variable "auth_lambda_name" {
  description = "Name of the auth Lambda function"
  type        = string
}

# NEW: Input for the Get Result Lambda
variable "get_result_lambda_invoke_arn" {
  description = "Invoke ARN of the get_result Lambda function"
  type        = string
}

variable "get_result_lambda_name" {
  description = "Name of the get_result Lambda function"
  type        = string
}
