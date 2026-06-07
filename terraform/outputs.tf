output "api_url" {
  description = "API Gateway base URL"
  value       = module.api.api_url
}

output "api_rest_api_id" {
  description = "API Gateway REST API ID"
  value       = module.api.rest_api_id
}
