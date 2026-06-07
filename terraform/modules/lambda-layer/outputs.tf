output "arn" {
  description = "Lambda Layer ARN"
  value       = aws_lambda_layer_version.shared.arn
}

output "version" {
  description = "Lambda Layer version"
  value       = aws_lambda_layer_version.shared.version
}
