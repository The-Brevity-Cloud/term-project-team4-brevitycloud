output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
  description = "ARN of the Lambda IAM role"
}

output "lambda_role_name" {
  description = "The name of the main Lambda execution role"
  value       = aws_iam_role.lambda_role.name
}

output "summarize_lambda_arn" {
  value = aws_lambda_function.summarize_lambda.arn
  description = "ARN of the summarize Lambda function"
}

output "summarize_lambda_invoke_arn" {
  value = aws_lambda_function.summarize_lambda.invoke_arn
  description = "Invoke ARN of the summarize Lambda function"
}

output "summarize_lambda_name" {
  value = aws_lambda_function.summarize_lambda.function_name
  description = "Name of the summarize Lambda function"
}

output "auth_lambda_arn" {
  value = aws_lambda_function.auth_lambda.arn
  description = "ARN of the auth Lambda function"
}

output "auth_lambda_invoke_arn" {
  value = aws_lambda_function.auth_lambda.invoke_arn
  description = "Invoke ARN of the auth Lambda function"
}

output "auth_lambda_name" {
  value = aws_lambda_function.auth_lambda.function_name
  description = "Name of the auth Lambda function"
}

# Outputs for invoker functions (ARN still needed by other modules, Name/InvokeARN removed)
output "invoke_rekognition_lambda_arn" {
  description = "ARN of the Rekognition invoker Lambda function"
  value       = aws_lambda_function.invoke_rekognition.arn
}

output "invoke_rekognition_lambda_name" {
  description = "Name of the Rekognition invoker Lambda function"
  value       = aws_lambda_function.invoke_rekognition.function_name
}

output "invoke_transcribe_lambda_arn" {
  description = "ARN of the Transcribe invoker Lambda function"
  value       = aws_lambda_function.invoke_transcribe.arn
}

output "invoke_transcribe_lambda_name" {
  description = "Name of the Transcribe invoker Lambda function"
  value       = aws_lambda_function.invoke_transcribe.function_name
}

output "get_result_lambda_arn" {
  description = "ARN of the get_result Lambda function"
  value       = aws_lambda_function.get_result.arn
}

output "get_result_lambda_invoke_arn" {
  description = "Invoke ARN of the get_result Lambda function"
  value       = aws_lambda_function.get_result.invoke_arn
}

output "get_result_lambda_name" {
  description = "Name of the get_result Lambda function"
  value       = aws_lambda_function.get_result.function_name
}
