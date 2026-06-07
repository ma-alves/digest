output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.digest.dashboard_name
}

output "workflow_alarm_arn" {
  description = "Workflow failure alarm ARN"
  value       = aws_cloudwatch_metric_alarm.workflow_failure.arn
}
