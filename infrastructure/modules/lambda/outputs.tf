output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
  description = "ARN of the Lambda IAM role"
}

output "lambda_role_name" {
  value = aws_iam_role.lambda_role.name
  description = "Name of the Lambda IAM role"
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
