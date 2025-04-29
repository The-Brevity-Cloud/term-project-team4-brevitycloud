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

variable "cognito_client_id" {
  description = "Cognito User Pool Client ID for JWT authorizer"
  type        = string
}

variable "cognito_issuer_url" {
  description = "Cognito User Pool Issuer URL for JWT authorizer (e.g., cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxx)"
  type        = string
}

variable "invoke_rekognition_lambda_invoke_arn" {
  description = "Invoke ARN of the invoke_rekognition Lambda function"
  type        = string
}

variable "invoke_rekognition_lambda_name" {
  description = "Name of the invoke_rekognition Lambda function"
  type        = string
}

variable "invoke_transcribe_lambda_invoke_arn" {
  description = "Invoke ARN of the invoke_transcribe Lambda function"
  type        = string
}

variable "invoke_transcribe_lambda_name" {
  description = "Name of the invoke_transcribe Lambda function"
  type        = string
}
