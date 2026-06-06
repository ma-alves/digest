output "api_url" {
  description = "API Gateway base URL"
  value       = "${aws_api_gateway_stage.v1.invoke_url}/"
}

output "rest_api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.api.id
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.v1.stage_name
}
