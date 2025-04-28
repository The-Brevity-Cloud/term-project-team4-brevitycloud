output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "rekognition_task_definition_arn" {
  description = "The ARN of the Rekognition task definition"
  value       = aws_ecs_task_definition.rekognition.arn
}

output "transcribe_task_definition_arn" {
  description = "The ARN of the Transcribe task definition"
  value       = aws_ecs_task_definition.transcribe.arn
}

output "transcribe_service_name" {
  description = "The name of the Transcribe ECS service"
  value       = aws_ecs_service.transcribe.name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "rekognition_task_role_arn" {
  description = "The ARN of the Rekognition Task Role"
  value       = aws_iam_role.rekognition_task_role.arn
}

output "transcribe_task_role_arn" {
  description = "The ARN of the Transcribe Task Role"
  value       = aws_iam_role.transcribe_task_role.arn
} 