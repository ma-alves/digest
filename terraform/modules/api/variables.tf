variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "subscribe_handler_invoke_arn" {
  description = "Invoke ARN for the subscribe-handler Lambda"
  type        = string
}

variable "subscribe_handler_name" {
  description = "Name of the subscribe-handler Lambda"
  type        = string
}

variable "list_subscribers_invoke_arn" {
  description = "Invoke ARN for the list-subscribers Lambda"
  type        = string
}

variable "list_subscribers_name" {
  description = "Name of the list-subscribers Lambda"
  type        = string
}

variable "unsubscribe_handler_invoke_arn" {
  description = "Invoke ARN for the unsubscribe-handler Lambda"
  type        = string
}

variable "unsubscribe_handler_name" {
  description = "Name of the unsubscribe-handler Lambda"
  type        = string
}
