variable "project_name" {
  description = "Name of the project used as prefix for resources"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the summarize lambda zip file"
  type        = string
}

variable "auth_lambda_zip_path" {
  description = "Path to the auth lambda zip file"
  type        = string
}

variable "kendra_index_id" {
  description = "ID of the Kendra index"
  type        = string
  default     = ""
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  type        = string
}

variable "cognito_client_id" {
  description = "ID of the Cognito user pool client"
  type        = string
}
