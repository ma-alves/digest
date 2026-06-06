variable "name" {
  description = "Lambda function name"
  type        = string
}

variable "handler" {
  description = "Lambda handler (e.g. index.handler)"
  type        = string
  default     = "index.handler"
}

variable "source_zip" {
  description = "Path to the Lambda deployment zip"
  type        = string
}

variable "layer_arn" {
  description = "ARN of the shared Lambda Layer"
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "env_vars" {
  description = "Environment variables for the Lambda"
  type        = map(string)
  default     = {}
}

variable "policy_arns" {
  description = "List of IAM policy ARNs to attach"
  type        = list(string)
  default     = []
}
