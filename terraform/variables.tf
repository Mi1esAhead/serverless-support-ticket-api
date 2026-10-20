variable "region" {
  type    = string
  default = "us-east-1"
}

variable "hosted_zone_name" {
  type        = string
  description = "Existing Route 53 hosted zone, e.g. m1portfolio.com"
}

variable "api_hostname" {
  type        = string
  description = "Public hostname for the API, e.g. tickets-api.m1portfolio.com"
}

variable "allowed_origins" {
  type        = list(string)
  description = "Browser origins allowed to call the API (CORS)"
}

variable "alert_email" {
  type        = string
  description = "Where the spike alarm and budget alerts are sent"
}

variable "image_tag" {
  type        = string
  default     = "v1"
  description = "ECR image tag the Lambda runs. Bump it to deploy new code."
}

variable "demo_enabled" {
  type        = bool
  default     = true
  description = "The on/off switch. false = Lambda concurrency 0, so every request fails."
}

variable "ticket_ttl_days" {
  type    = number
  default = 1
}

variable "throttle_rate" {
  type        = number
  default     = 5
  description = "Sustained requests per second allowed through API Gateway"
}

variable "throttle_burst" {
  type    = number
  default = 10
}

variable "spike_threshold" {
  type        = number
  default     = 300
  description = "Lambda invocations per 5 minutes that trigger the alarm"
}

variable "monthly_budget_usd" {
  type    = number
  default = 5
}