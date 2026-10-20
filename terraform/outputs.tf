output "api_url" {
  value = "https://${var.api_hostname}"
}

output "api_gateway_default_url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}

output "ticket_bucket" {
  value = aws_s3_bucket.tickets.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}