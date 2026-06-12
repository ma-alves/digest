output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.workflow.arn
}

output "failure_topic_arn" {
  description = "SNS failure topic ARN"
  value       = aws_sns_topic.failure_alerts.arn
}

output "schedule_arn" {
  description = "EventBridge schedule ARN"
  value       = aws_scheduler_schedule.daily.arn
}

output "scheduler_dlq_arn" {
  description = "Scheduler dead letter queue ARN"
  value       = aws_sqs_queue.scheduler_dlq.arn
}
