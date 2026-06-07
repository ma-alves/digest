resource "aws_sns_topic" "failure_alerts" {
  name = "${var.name_prefix}-newsletter-failures"
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.failure_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_invoke_lambdas" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [
      var.fetch_articles_arn,
      var.generate_newsletter_arn,
      var.send_emails_arn,
      var.mark_status_arn,
      var.notify_failure_arn,
    ]
  }
}

resource "aws_iam_role" "step_functions" {
  name               = "${var.name_prefix}-step-functions-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

resource "aws_iam_role_policy" "invoke_lambdas" {
  name   = "${var.name_prefix}-sfn-invoke-lambdas"
  role   = aws_iam_role.step_functions.name
  policy = data.aws_iam_policy_document.sfn_invoke_lambdas.json
}

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${var.name_prefix}-newsletter-workflow"
  retention_in_days = 30
}

resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.name_prefix}-newsletter-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile("${path.module}/templates/workflow.json.tpl", {
    fetch_articles_arn      = var.fetch_articles_arn
    generate_newsletter_arn = var.generate_newsletter_arn
    send_emails_arn         = var.send_emails_arn
    mark_status_arn         = var.mark_status_arn
    notify_failure_arn      = var.notify_failure_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }
}

resource "aws_iam_role" "scheduler" {
  name = "${var.name_prefix}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_sfn" {
  name = "${var.name_prefix}-scheduler-invoke-sfn"
  role = aws_iam_role.scheduler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.workflow.arn
    }]
  })
}

resource "aws_scheduler_schedule" "daily" {
  name                         = "${var.name_prefix}-daily-trigger"
  schedule_expression          = "cron(0 8 * * ? *)"
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.workflow.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({})
  }
}
