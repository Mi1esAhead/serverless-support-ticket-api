# ---------- IAM: what the function is allowed to do ----------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "ticket-demo-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "tickets_access" {
  statement {
    sid       = "ReadWriteTickets"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.tickets.arn}/tickets/*"]
  }

  # Without list permission, S3 answers 403 (not 404) for missing keys.
  statement {
    sid       = "ListSoMissingKeysReturn404"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tickets.arn]
  }
}

resource "aws_iam_role_policy" "tickets_access" {
  name   = "tickets-bucket-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.tickets_access.json
}

# ---------- Lambda (runs the Docker image) ----------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/ticket-demo-api"
  retention_in_days = 7
}

resource "aws_lambda_function" "api" {
  function_name = "ticket-demo-api"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
  architectures = ["x86_64"]
  memory_size   = 512
  timeout       = 10

  # THE ON/OFF SWITCH: -1 = unreserved (running), 0 = every invocation is throttled.
  reserved_concurrent_executions = var.demo_enabled ? -1 : 0

  environment {
    variables = {
      TICKET_BUCKET = aws_s3_bucket.tickets.id
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_logs,
  ]
}

# ---------- API Gateway (public front door) ----------
resource "aws_apigatewayv2_api" "http" {
  name          = "ticket-demo-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# One catch-all route: FastAPI does the routing inside the container.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate
    throttling_burst_limit = var.throttle_burst
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}