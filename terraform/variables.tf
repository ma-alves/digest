variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "digest"
}

variable "newsapi_key" {
  description = "NewsAPI key (sensitive)"
  type        = string
  sensitive   = true
}

variable "search_query" {
  description = "NewsAPI search query"
  type        = string
  default     = "technology"
}

variable "language" {
  description = "NewsAPI language filter"
  type        = string
  default     = "en"
}

variable "article_count" {
  description = "Number of articles to fetch"
  type        = number
  default     = 10
}

variable "from_email" {
  description = "SES verified sender email"
  type        = string
}

variable "admin_email" {
  description = "Admin email for failure notifications"
  type        = string
}

variable "max_retries" {
  description = "Max SES send retries per batch"
  type        = number
  default     = 3
}

variable "shared_layer_zip_path" {
  description = "Path to the shared Lambda Layer zip"
  type        = string
  default     = "../terraform/lambda-packages/digest-shared-layer.zip"
}

variable "subscribe_handler_zip" {
  description = "Path to subscribe-handler zip"
  type        = string
  default     = "../terraform/lambda-packages/subscribe-handler.zip"
}

variable "list_subscribers_zip" {
  description = "Path to list-subscribers zip"
  type        = string
  default     = "../terraform/lambda-packages/list-subscribers.zip"
}

variable "unsubscribe_handler_zip" {
  description = "Path to unsubscribe-handler zip"
  type        = string
  default     = "../terraform/lambda-packages/unsubscribe-handler.zip"
}

variable "fetch_articles_zip" {
  description = "Path to fetch-articles zip"
  type        = string
  default     = "../terraform/lambda-packages/fetch-articles.zip"
}

variable "generate_newsletter_zip" {
  description = "Path to generate-newsletter zip"
  type        = string
  default     = "../terraform/lambda-packages/generate-newsletter.zip"
}

variable "send_emails_zip" {
  description = "Path to send-emails zip"
  type        = string
  default     = "../terraform/lambda-packages/send-emails.zip"
}

variable "mark_newsletter_status_zip" {
  description = "Path to mark-newsletter-status zip"
  type        = string
  default     = "../terraform/lambda-packages/mark-newsletter-status.zip"
}

variable "notify_failure_zip" {
  description = "Path to notify-failure zip"
  type        = string
  default     = "../terraform/lambda-packages/notify-failure.zip"
}
