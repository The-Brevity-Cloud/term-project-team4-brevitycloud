variable "project_name" {
  description = "Name of the project used as prefix for resources"
  type        = string
}

variable "api_gateway_id" {
  description = "ID of the API Gateway"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for temporary audio storage"
  type        = string
}

variable "invoke_transcribe_lambda_arn" {
  description = "ARN of the Lambda function that invokes the Transcribe ECS task"
  type        = string
}

variable "invoke_transcribe_lambda_name" {
  description = "Name of the Lambda function that invokes the Transcribe ECS task"
  type        = string
}

variable "transcribe_policy_arn" {
  description = "ARN of the IAM policy granting Transcribe permissions"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonTranscribeFullAccess" # Defaulting to full access
} 