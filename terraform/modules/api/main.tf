resource "aws_api_gateway_rest_api" "api" {
  name = "${var.name_prefix}-api"
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "subscribers" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "subscribers"
}

resource "aws_api_gateway_resource" "unsubscribe" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "unsubscribe"
}

resource "aws_api_gateway_method" "subscribe_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.subscribers.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.subscribers.id
  http_method             = aws_api_gateway_method.subscribe_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.subscribe_handler_invoke_arn
}

resource "aws_lambda_permission" "subscribe_post" {
  statement_id  = "AllowAPIGatewayInvokeSubscribe"
  action        = "lambda:InvokeFunction"
  function_name = var.subscribe_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/POST/api/v1/subscribers"
}

resource "aws_api_gateway_method" "subscribers_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.subscribers.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribers_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.subscribers.id
  http_method             = aws_api_gateway_method.subscribers_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.list_subscribers_invoke_arn
}

resource "aws_lambda_permission" "subscribers_get" {
  statement_id  = "AllowAPIGatewayInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = var.list_subscribers_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/GET/api/v1/subscribers"
}

resource "aws_api_gateway_method" "unsubscribe_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.unsubscribe.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "unsubscribe_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.unsubscribe.id
  http_method             = aws_api_gateway_method.unsubscribe_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.unsubscribe_handler_invoke_arn
}

resource "aws_lambda_permission" "unsubscribe_get" {
  statement_id  = "AllowAPIGatewayInvokeUnsubscribe"
  action        = "lambda:InvokeFunction"
  function_name = var.unsubscribe_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/GET/unsubscribe"
}

resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [
    aws_api_gateway_integration.subscribe_post,
    aws_api_gateway_integration.subscribers_get,
    aws_api_gateway_integration.unsubscribe_get,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.subscribers.id,
      aws_api_gateway_method.subscribe_post.id,
      aws_api_gateway_method.subscribers_get.id,
      aws_api_gateway_resource.unsubscribe.id,
      aws_api_gateway_method.unsubscribe_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "v1"
}
