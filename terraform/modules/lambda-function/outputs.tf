output "arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.this.arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN (for API Gateway)"
  value       = aws_lambda_function.this.invoke_arn
}
