output "subscribers_table_name" {
  description = "Subscribers DynamoDB table name"
  value       = aws_dynamodb_table.subscribers.name
}

output "subscribers_table_arn" {
  description = "Subscribers DynamoDB table ARN"
  value       = aws_dynamodb_table.subscribers.arn
}

output "newsletters_table_name" {
  description = "Newsletters DynamoDB table name"
  value       = aws_dynamodb_table.newsletters.name
}

output "newsletters_table_arn" {
  description = "Newsletters DynamoDB table ARN"
  value       = aws_dynamodb_table.newsletters.arn
}

output "template_bucket_id" {
  description = "Template S3 bucket ID"
  value       = aws_s3_bucket.template.id
}

output "template_bucket_arn" {
  description = "Template S3 bucket ARN"
  value       = aws_s3_bucket.template.arn
}

output "html_bucket_id" {
  description = "Rendered HTML S3 bucket ID"
  value       = aws_s3_bucket.html.id
}

output "html_bucket_arn" {
  description = "Rendered HTML S3 bucket ARN"
  value       = aws_s3_bucket.html.arn
}
