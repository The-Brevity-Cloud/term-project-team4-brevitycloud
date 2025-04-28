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

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for webpage content storage"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for webpage content"
  type        = string
}

# --- NEW: Inputs for ECS Invoker Lambdas ---
variable "rekognition_lambda_zip_path" {
  description = "Path to the Rekognition invoker Lambda deployment package"
  type        = string
  # default = "../infrastructure/lambda_function_invoke_rekognition.zip" # Example if path is stable
}

variable "transcribe_lambda_zip_path" {
  description = "Path to the Transcribe invoker Lambda deployment package"
  type        = string
  # default = "../infrastructure/lambda_function_invoke_transcribe.zip" # Example
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster the invoker Lambdas will target"
  type        = string
}

variable "rekognition_task_def_arn" {
  description = "ARN of the Rekognition ECS task definition"
  type        = string
}

variable "transcribe_task_def_arn" {
  description = "ARN of the Transcribe ECS task definition"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS task placement"
  type        = list(string)
}

variable "task_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "ecs_rekognition_task_role_arn" {
  description = "ARN of the IAM role assumed by the Rekognition ECS task"
  type        = string
}

variable "ecs_transcribe_task_role_arn" {
  description = "ARN of the IAM role assumed by the Transcribe ECS task"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution Role (passed TO ECS tasks)"
  type        = string
}

variable "environment" {
  description = "Deployment environment tag value"
  type        = string
  default     = "dev"
}

# NEW: Path for get_result lambda
variable "get_result_lambda_zip_path" {
  description = "Path to the get_result Lambda deployment package"
  type        = string
}