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

variable "invoke_rekognition_lambda_arn" {
  description = "ARN of the Lambda function that invokes the Rekognition ECS task"
  type        = string
}

variable "invoke_rekognition_lambda_name" {
  description = "Name of the Lambda function that invokes the Rekognition ECS task"
  type        = string
}

variable "rekognition_policy_arn" {
  description = "ARN of the IAM policy granting Rekognition permissions"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonRekognitionFullAccess"
} 