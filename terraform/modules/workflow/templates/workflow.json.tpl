{
  "Comment": "Digest Newsletter — Daily Workflow",
  "StartAt": "FetchArticles",
  "States": {
    "FetchArticles": {
      "Type": "Task",
      "Resource": "${fetch_articles_arn}",
      "ResultPath": "$.articles",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
          "IntervalSeconds": 30,
          "MaxAttempts": 2,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "GenerateNewsletter"
    },
    "GenerateNewsletter": {
      "Type": "Task",
      "Resource": "${generate_newsletter_arn}",
      "Parameters": {
        "articles.$": "$.articles",
        "generatedAt.$": "$$.State.EnteredTime"
      },
      "ResultPath": "$.newsletter",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "SendEmails"
    },
    "SendEmails": {
      "Type": "Task",
      "Resource": "${send_emails_arn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "htmlS3Key.$": "$.newsletter.htmlS3Key"
      },
      "ResultPath": "$.sendResult",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
          "IntervalSeconds": 10,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "MarkSent"
    },
    "MarkSent": {
      "Type": "Task",
      "Resource": "${mark_status_arn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "status": "SENT",
        "sendResult.$": "$.sendResult"
      },
      "End": true
    },
    "MarkFailed": {
      "Type": "Task",
      "Resource": "${mark_status_arn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "status": "FAILED",
        "error.$": "$.error"
      },
      "Next": "NotifyFailure"
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "${notify_failure_arn}",
      "End": true
    }
  }
}
