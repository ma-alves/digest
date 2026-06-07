resource "aws_cloudwatch_dashboard" "digest" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", { stat = "Sum" }],
            ["AWS/States", "ExecutionsFailed",  { stat = "Sum" }],
          ]
          period = 86400
          stat   = "Sum"
          region = var.region
          title  = "Step Functions — Daily Executions"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            ["AWS/Lambda", "Errors",       { stat = "Sum" }],
            ["AWS/Lambda", "Duration",     { stat = "p50" }],
            ["AWS/Lambda", "Duration",     { stat = "p99" }],
          ]
          period = 3600
          region = var.region
          title  = "Lambda — Aggregated Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", { stat = "Sum" }],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits",  { stat = "Sum" }],
          ]
          period = 3600
          region = var.region
          title  = "DynamoDB — Consumed Capacity"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SES", "Send",       { stat = "Sum" }],
            ["AWS/SES", "Bounce",     { stat = "Sum" }],
            ["AWS/SES", "Complaint",  { stat = "Sum" }],
          ]
          period = 3600
          region = var.region
          title  = "SES — Send Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", { stat = "Sum" }],
            ["AWS/ApiGateway", "5XXError", { stat = "Sum" }],
            ["AWS/ApiGateway", "Latency",  { stat = "p99" }],
          ]
          period = 3600
          region = var.region
          title  = "API Gateway — Errors & Latency"
        }
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "workflow_failure" {
  alarm_name          = "${var.name_prefix}-workflow-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "ExecutionsFailed"
      namespace   = "AWS/States"
      period      = 86400
      stat        = "Sum"
    }
  }

  alarm_actions = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  alarm_name          = "${var.name_prefix}-ses-bounce-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5

  metric_query {
    id          = "bounces"
    return_data = false

    metric {
      metric_name = "Bounce"
      namespace   = "AWS/SES"
      period      = 86400
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "sends"
    return_data = false

    metric {
      metric_name = "Send"
      namespace   = "AWS/SES"
      period      = 86400
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "rate"
    expression  = "(bounces / sends) * 100"
    label       = "Bounce Rate"
    return_data = true
  }

  alarm_actions = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 86400
      stat        = "Sum"
    }
  }

  alarm_actions = [var.sns_topic_arn]
}
