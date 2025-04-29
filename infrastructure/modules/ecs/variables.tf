variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security Group ID to attach to ECS tasks"
  type        = string
}

variable "rekognition_image_uri" {
  description = "ECR image URI for the Rekognition service container"
  type        = string
}

variable "transcribe_image_uri" {
  description = "ECR image URI for the Transcribe service container"
  type        = string
}

variable "rekognition_task_cpu" {
  description = "CPU units for the Rekognition task"
  type        = number
  default     = 256 # 0.25 vCPU
}

variable "rekognition_task_memory" {
  description = "Memory (in MiB) for the Rekognition task"
  type        = number
  default     = 512 # 0.5 GB
}

variable "transcribe_task_cpu" {
  description = "CPU units for the Transcribe task"
  type        = number
  default     = 256 # 0.25 vCPU
}

variable "transcribe_task_memory" {
  description = "Memory (in MiB) for the Transcribe task"
  type        = number
  default     = 512 # 0.5 GB
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for task role permissions"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for task role permissions (if needed)"
  type        = string
  default     = null # Optional, depends on container logic
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain logs in CloudWatch Log Group"
  type        = number
  default     = 7
}

variable "transcribe_service_desired_count" {
  description = "Initial desired number of tasks for the Transcribe service"
  type        = number
  default     = 1
}

variable "transcribe_service_min_capacity" {
  description = "Minimum number of tasks for Transcribe service auto-scaling"
  type        = number
  default     = 1
}

variable "transcribe_service_max_capacity" {
  description = "Maximum number of tasks for Transcribe service auto-scaling"
  type        = number
  default     = 3 # Example max capacity
}

variable "transcribe_scaling_cpu_target" {
  description = "Target average CPU utilization (percentage) for Transcribe service auto-scaling"
  type        = number
  default     = 75 # Target 75% CPU
}

# Add other variables as needed, e.g., for memory scaling target
# variable "transcribe_scaling_memory_target" { ... }

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used for inputs/outputs"
  type        = string
} 