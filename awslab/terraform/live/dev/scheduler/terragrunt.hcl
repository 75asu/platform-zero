include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/scheduler"
}

dependency "lambda" {
  config_path = "../lambda"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    orders_analytics_arn = "arn:aws:lambda:us-east-1:000000000000:function:mock-analytics"
    s3_processor_arn     = "arn:aws:lambda:us-east-1:000000000000:function:mock-s3-processor"
  }
}

inputs = {
  environment = "dev"

  lambda_target_arns = [
    dependency.lambda.outputs.orders_analytics_arn,
    dependency.lambda.outputs.s3_processor_arn,
  ]

  schedules = {
    # Nightly cleanup: runs at 02:00 UTC every day.
    # Invokes orders-analytics to aggregate the previous day's data.
    nightly-cleanup = {
      expression = "cron(0 2 * * ? *)"
      lambda_arn = dependency.lambda.outputs.orders_analytics_arn
      payload    = { mode = "nightly-cleanup" }
    }

    # Hourly metrics: aggregates order counts every hour.
    # In production: feeds a metrics dashboard or SLI reporting.
    hourly-metrics = {
      expression = "rate(1 hour)"
      lambda_arn = dependency.lambda.outputs.orders_analytics_arn
      payload    = { mode = "aggregate" }
    }
  }

  timezone           = "UTC"
  max_retry_attempts = 2
}
