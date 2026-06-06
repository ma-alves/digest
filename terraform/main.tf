provider "aws" {
  region = var.region
}

module "database" {
  source = "./modules/database"

  name_prefix = var.name_prefix
}

module "lambda_layer" {
  source = "./modules/lambda-layer"

  name_prefix    = var.name_prefix
  layer_zip_path = var.shared_layer_zip_path
}

# lambda handlers
module "subscribe_handler" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-subscribe-handler"
  handler     = "index.handler"
  source_zip  = var.subscribe_handler_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 128
  timeout     = 10
  env_vars = {
    SUBSCRIBERS_TABLE = module.database.subscribers_table_name
  }
  policy_arns = [aws_iam_policy.subscribe_handler_dynamo.arn]
}

module "list_subscribers" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-list-subscribers"
  handler     = "index.handler"
  source_zip  = var.list_subscribers_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 128
  timeout     = 10
  env_vars = {
    SUBSCRIBERS_TABLE = module.database.subscribers_table_name
  }
  policy_arns = [aws_iam_policy.list_subscribers_dynamo.arn]
}

module "unsubscribe_handler" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-unsubscribe-handler"
  handler     = "index.handler"
  source_zip  = var.unsubscribe_handler_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 128
  timeout     = 10
  env_vars = {
    SUBSCRIBERS_TABLE = module.database.subscribers_table_name
  }
  policy_arns = [aws_iam_policy.unsubscribe_handler_dynamo.arn]
}

module "api" {
  source = "./modules/api"

  name_prefix                   = var.name_prefix
  subscribe_handler_invoke_arn  = module.subscribe_handler.invoke_arn
  subscribe_handler_name        = module.subscribe_handler.name
  list_subscribers_invoke_arn   = module.list_subscribers.invoke_arn
  list_subscribers_name         = module.list_subscribers.name
  unsubscribe_handler_invoke_arn = module.unsubscribe_handler.invoke_arn
  unsubscribe_handler_name      = module.unsubscribe_handler.name
}

# iam policies
resource "aws_iam_policy" "subscribe_handler_dynamo" {
  name        = "${var.name_prefix}-subscribe-handler-dynamo"
  description = "Allow PutItem on subscribers table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = module.database.subscribers_table_arn
    }]
  })
}

resource "aws_iam_policy" "list_subscribers_dynamo" {
  name        = "${var.name_prefix}-list-subscribers-dynamo"
  description = "Allow Scan on subscribers table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:Scan"]
      Resource = module.database.subscribers_table_arn
    }]
  })
}

resource "aws_iam_policy" "unsubscribe_handler_dynamo" {
  name        = "${var.name_prefix}-unsubscribe-handler-dynamo"
  description = "Allow UpdateItem on subscribers table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem"]
      Resource = module.database.subscribers_table_arn
    }]
  })
}
