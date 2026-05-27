locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Handler zips ───────────────────────────────────────────────────────────────
# archive_file creates the zip at plan time from the handler source files.
# output_path is placed inside the module directory (next to the handlers/).
# Terraform tracks file hash changes — any handler edit triggers a function update.
data "archive_file" "orders_analytics" {
  type        = "zip"
  source_file = "${path.module}/handlers/orders_analytics.py"
  output_path = "${path.module}/handlers/orders_analytics.zip"
}

data "archive_file" "s3_processor" {
  type        = "zip"
  source_file = "${path.module}/handlers/s3_processor.py"
  output_path = "${path.module}/handlers/s3_processor.zip"
}

# ── Lambda security group ──────────────────────────────────────────────────────
# VPC-attached Lambda needs a SG. Ingress is irrelevant (Lambda isn't a server).
# Egress: open — functions need to call AWS APIs (SSM, Secrets Manager, SQS, RDS).
# Real AWS: scope egress to RDS SG (5432), ElastiCache SG (6379), HTTPS (443).
resource "aws_security_group" "lambda" {
  count = var.vpc_id != "" ? 1 : 0

  name        = "${local.name}-lambda"
  description = "Lambda functions egress - VPC to AWS APIs and data tier"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound - AWS API calls and data tier access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-lambda"
  })
}

# ── Analytics SQS queue ────────────────────────────────────────────────────────
# Dedicated queue for the Lambda analytics consumer.
# SNS subscribes this queue → orders analytics data flows here.
# Separate from the main orders queue so analytics failures don't block fulfilment.
resource "aws_sqs_queue" "analytics_dlq" {
  name                      = "${local.name}-analytics-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = merge(local.common_tags, {
    Name = "${local.name}-analytics-dlq"
    Role = "dead-letter-queue"
  })
}

resource "aws_sqs_queue" "analytics" {
  name                       = "${local.name}-analytics"
  visibility_timeout_seconds = 300 # matches Lambda timeout
  receive_wait_time_seconds  = 20  # long polling
  message_retention_seconds  = 345600 # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.analytics_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Name = "${local.name}-analytics"
    Role = "analytics-queue"
  })
}

# Allow SNS to write to the analytics queue (required for SNS subscription delivery).
resource "aws_sqs_queue_policy" "analytics" {
  queue_url = aws_sqs_queue.analytics.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSDelivery"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = ["sqs:SendMessage"]
      Resource  = aws_sqs_queue.analytics.arn
      Condition = {
        ArnLike = { "aws:SourceArn" = var.sns_topic_arn }
      }
    }]
  })
}

# ── orders-analytics Lambda ────────────────────────────────────────────────────
# SQS consumer: reads from the analytics queue, processes order events.
# VPC-attached so it can reach ElastiCache (Redis) for caching aggregates.
resource "aws_lambda_function" "orders_analytics" {
  function_name = "${local.name}-orders-analytics"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "orders_analytics.handler"
  runtime       = var.runtime
  timeout       = var.function_timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.orders_analytics.output_path
  source_code_hash = data.archive_file.orders_analytics.output_base64sha256

  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
        PROJECT     = var.project
        LOG_LEVEL   = var.log_level
      },
      var.extra_env_vars,
    )
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name}-orders-analytics"
    Purpose = "analytics-consumer"
  })
}

# ── SQS event source mapping ───────────────────────────────────────────────────
# Lambda polls the analytics queue and invokes orders_analytics for each batch.
# batch_size = 10: up to 10 messages per invocation (SQS standard queue max = 10000).
# bisect_on_function_error = true: on failure, splits the batch in half and retries
# each half separately — narrows down the bad message without retrying good ones.
resource "aws_lambda_event_source_mapping" "analytics_sqs" {
  event_source_arn = aws_sqs_queue.analytics.arn
  function_name    = aws_lambda_function.orders_analytics.arn
  batch_size       = var.sqs_batch_size
  enabled          = true

  # SQS partial-failure handling: Lambda reports individual message failures
  # back to SQS rather than failing the whole batch.
  # Note: bisect_on_function_error is Kinesis/DynamoDB only — not applicable to SQS.
  function_response_types = ["ReportBatchItemFailures"]
}

# ── s3-processor Lambda ────────────────────────────────────────────────────────
# S3 event processor: triggered on object creation in the app data bucket.
# Not VPC-attached — it only needs S3 and doesn't need private subnet resources.
resource "aws_lambda_function" "s3_processor" {
  function_name = "${local.name}-s3-processor"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "s3_processor.handler"
  runtime       = var.runtime
  timeout       = var.function_timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.s3_processor.output_path
  source_code_hash = data.archive_file.s3_processor.output_base64sha256

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
        PROJECT     = var.project
        LOG_LEVEL   = var.log_level
      },
      var.extra_env_vars,
    )
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name}-s3-processor"
    Purpose = "s3-event-processor"
  })
}

# ── S3 → Lambda trigger permission ────────────────────────────────────────────
# S3 needs permission to invoke the Lambda function when an object is created.
# Without this, S3 sends the notification but Lambda refuses it (403).
resource "aws_lambda_permission" "s3_invoke" {
  count = var.s3_bucket_arn != "" ? 1 : 0

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

# ── S3 bucket notification ─────────────────────────────────────────────────────
# Wires S3 object creation events to the s3_processor function.
# filter_prefix/suffix: scope to specific key patterns (e.g. uploads/, .json).
# Real AWS: use EventBridge notifications for more filtering power and fan-out.
resource "aws_s3_bucket_notification" "trigger" {
  count  = var.s3_bucket_id != "" ? 1 : 0
  bucket = var.s3_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_filter_prefix
    filter_suffix       = var.s3_filter_suffix
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
