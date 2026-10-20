# A public endpoint that accepts writes needs limits and alerts.
# (Throttling lives in api.tf; the on/off switch is var.demo_enabled.)

resource "aws_sns_topic" "alerts" {
  name = "ticket-demo-alerts"
}

# Email subscriptions must be confirmed: click the link AWS emails you.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "invocation_spike" {
  alarm_name          = "ticket-demo-invocation-spike"
  alarm_description   = "Unusual traffic on the public demo API. Consider switching it off."
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.spike_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
}

# Account-wide budget (no filter), a backstop in case something else goes wrong.
resource "aws_budgets_budget" "monthly" {
  name         = "ticket-demo-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}