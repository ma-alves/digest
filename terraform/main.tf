provider "aws" {
  region = var.region
}

# --- Database ---
module "database" {
  source = "./modules/database"

  name_prefix = var.name_prefix
}

# --- Template upload ---
resource "aws_s3_object" "template" {
  bucket = module.database.template_bucket_id
  key    = "template.hbs"
  source = "../handlers/generate-newsletter/template.hbs"
  etag   = filemd5("../handlers/generate-newsletter/template.hbs")
  content_type = "text/x-handlebars"
}

# --- Lambda Layer (shared code) ---
module "lambda_layer" {
  source = "./modules/lambda-layer"

  name_prefix    = var.name_prefix
  layer_zip_path = var.shared_layer_zip_path
}

# --- Lambda Functions (API handlers) ---
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

# --- Lambda Functions (workflow handlers) ---
module "fetch_articles" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-fetch-articles"
  handler     = "index.handler"
  source_zip  = var.fetch_articles_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 256
  timeout     = 30
  env_vars = {
    NEWSAPI_KEY_ARN = aws_secretsmanager_secret.newsapi_key.arn
    SEARCH_QUERY    = var.search_query
    LANGUAGE        = var.language
    ARTICLE_COUNT   = var.article_count
  }
  policy_arns = [aws_iam_policy.fetch_articles_secrets.arn]
}

module "generate_newsletter" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-generate-newsletter"
  handler     = "index.handler"
  source_zip  = var.generate_newsletter_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 256
  timeout     = 30
  env_vars = {
    TEMPLATE_BUCKET     = module.database.template_bucket_id
    TEMPLATE_KEY        = "template.hbs"
    NEWSLETTERS_TABLE   = module.database.newsletters_table_name
    HTML_BUCKET         = module.database.html_bucket_id
  }
  policy_arns = [
    aws_iam_policy.generate_newsletter_s3.arn,
    aws_iam_policy.generate_newsletter_dynamo.arn,
  ]
}

module "send_emails" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-send-emails"
  handler     = "index.handler"
  source_zip  = var.send_emails_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 512
  timeout     = 120
  env_vars = {
    SUBSCRIBERS_TABLE = module.database.subscribers_table_name
    NEWSLETTERS_TABLE = module.database.newsletters_table_name
    FROM_EMAIL        = var.from_email
    MAX_RETRIES       = var.max_retries
    HTML_BUCKET       = module.database.html_bucket_id
  }
  policy_arns = [
    aws_iam_policy.send_emails_dynamo.arn,
    aws_iam_policy.send_emails_ses.arn,
    aws_iam_policy.send_emails_s3.arn,
  ]
}

module "mark_newsletter_status" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-mark-newsletter-status"
  handler     = "index.handler"
  source_zip  = var.mark_newsletter_status_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 128
  timeout     = 10
  env_vars = {
    NEWSLETTERS_TABLE = module.database.newsletters_table_name
  }
  policy_arns = [aws_iam_policy.mark_status_dynamo.arn]
}

module "notify_failure" {
  source = "./modules/lambda-function"

  name        = "${var.name_prefix}-notify-failure"
  handler     = "index.handler"
  source_zip  = var.notify_failure_zip
  layer_arn   = module.lambda_layer.arn
  memory_size = 128
  timeout     = 15
  env_vars = {
    SNS_TOPIC_ARN = module.workflow.failure_topic_arn
  }
  policy_arns = [aws_iam_policy.notify_failure_sns.arn]
}

# --- API Gateway ---
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

# --- Step Functions + EventBridge + SNS ---
module "workflow" {
  source = "./modules/workflow"

  name_prefix             = var.name_prefix
  fetch_articles_arn      = module.fetch_articles.arn
  generate_newsletter_arn = module.generate_newsletter.arn
  send_emails_arn         = module.send_emails.arn
  mark_status_arn         = module.mark_newsletter_status.arn
  notify_failure_arn      = module.notify_failure.arn
  admin_email             = var.admin_email
}

# --- Monitoring ---
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix   = var.name_prefix
  region        = var.region
  sns_topic_arn = module.workflow.failure_topic_arn
}

# --- Secrets ---
resource "aws_secretsmanager_secret" "newsapi_key" {
  name = "${var.name_prefix}-newsapi-key"
}

resource "aws_secretsmanager_secret_version" "newsapi_key" {
  secret_id     = aws_secretsmanager_secret.newsapi_key.id
  secret_string = var.newsapi_key
}

# --- IAM Policies (API handlers) ---
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

# --- IAM Policies (workflow handlers) ---
resource "aws_iam_policy" "fetch_articles_secrets" {
  name        = "${var.name_prefix}-fetch-articles-secrets"
  description = "Allow GetSecretValue on NewsAPI key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.newsapi_key.arn
    }]
  })
}

resource "aws_iam_policy" "generate_newsletter_s3" {
  name        = "${var.name_prefix}-generate-newsletter-s3"
  description = "Allow S3 GetObject (template) + PutObject (html)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${module.database.template_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${module.database.html_bucket_arn}/*"
      },
    ]
  })
}

resource "aws_iam_policy" "generate_newsletter_dynamo" {
  name        = "${var.name_prefix}-generate-newsletter-dynamo"
  description = "Allow PutItem on newsletters table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = module.database.newsletters_table_arn
    }]
  })
}

resource "aws_iam_policy" "send_emails_dynamo" {
  name        = "${var.name_prefix}-send-emails-dynamo"
  description = "Allow Scan on subscribers + UpdateItem on newsletters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Scan"]
        Resource = module.database.subscribers_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = module.database.newsletters_table_arn
      },
    ]
  })
}

resource "aws_iam_policy" "send_emails_ses" {
  name        = "${var.name_prefix}-send-emails-ses"
  description = "Allow SES SendEmail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "send_emails_s3" {
  name        = "${var.name_prefix}-send-emails-s3"
  description = "Allow S3 GetObject (html)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${module.database.html_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_policy" "mark_status_dynamo" {
  name        = "${var.name_prefix}-mark-status-dynamo"
  description = "Allow UpdateItem on newsletters table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem"]
      Resource = module.database.newsletters_table_arn
    }]
  })
}

resource "aws_iam_policy" "notify_failure_sns" {
  name        = "${var.name_prefix}-notify-failure-sns"
  description = "Allow SNS Publish"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = module.workflow.failure_topic_arn
    }]
  })
}
