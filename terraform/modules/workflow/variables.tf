variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "admin_email" {
  description = "Admin email for failure notifications"
  type        = string
}

variable "fetch_articles_arn" {
  description = "ARN of fetch-articles Lambda"
  type        = string
}

variable "generate_newsletter_arn" {
  description = "ARN of generate-newsletter Lambda"
  type        = string
}

variable "send_emails_arn" {
  description = "ARN of send-emails Lambda"
  type        = string
}

variable "mark_status_arn" {
  description = "ARN of mark-newsletter-status Lambda"
  type        = string
}

variable "notify_failure_arn" {
  description = "ARN of notify-failure Lambda"
  type        = string
}
