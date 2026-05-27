# modules/lambda

Two Python 3.12 Lambda functions: an SQS-triggered analytics consumer and an S3-triggered file processor. IAM execution role, VPC attachment, dedicated SQS queue with DLQ, and event source mappings all in one module.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `data.archive_file` (x2) | Creates handler .zip files from .py source at plan time |
| `aws_iam_role` - `lambda_execution` | Execution role assumed by Lambda service |
| `aws_iam_role_policy_attachment` - `lambda_vpc_execution` | Attaches AWSLambdaVPCAccessExecutionRole (ENI creation for VPC attachment) |
| `aws_iam_policy` - `lambda_app` | Custom policy: SQS consume, S3 read, SSM read |
| `aws_sqs_queue` - `analytics` | Dedicated input queue for the analytics function |
| `aws_sqs_queue` - `analytics_dlq` | Dead letter queue after max receive attempts |
| `aws_sqs_queue_policy` - `analytics` | Allows SNS service principal to deliver to analytics queue |
| `aws_security_group` - `lambda` | Egress-only SG for VPC-attached functions |
| `aws_lambda_function` - `orders_analytics` | SQS consumer - processes order events, runs in VPC |
| `aws_lambda_function` - `s3_processor` | S3 trigger - processes object creation events, not VPC-attached |
| `aws_lambda_event_source_mapping` - `analytics_sqs` | Polls analytics queue, invokes orders_analytics in batches |
| `aws_lambda_permission` - `s3_invoke` | Allows S3 to invoke s3_processor (conditional) |
| `aws_s3_bucket_notification` - `trigger` | Wires S3 object creation events to s3_processor (conditional) |

## Key concepts

**archive_file at plan time**
The `data.archive_file` data source zips the handler Python file during `terraform plan`. The zip is written to `handlers/*.zip` alongside the source. Terraform tracks the `source_code_hash` - any change to the .py file triggers a function update on the next apply. No external build step, no CI packaging needed.

**VPC attachment**
`orders_analytics` runs inside the VPC to reach RDS and ElastiCache directly on their private IPs. VPC attachment requires:
1. `AWSLambdaVPCAccessExecutionRole` - allows the Lambda service to create and manage ENIs in the target subnets
2. A security group for the function's outbound traffic
3. Private subnet IDs where ENIs are placed

The ENI creation adds about 10-20s to cold start time for the first invocation. Warm invocations reuse the ENI. `s3_processor` does not need VPC access and skips attachment.

**SQS event source mapping**
Lambda polls the analytics queue automatically via `aws_lambda_event_source_mapping`. Key parameters:
- `batch_size = 10` - up to 10 messages per Lambda invocation
- `function_response_types = ["ReportBatchItemFailures"]` - the function returns a list of failed message IDs. Lambda only deletes the messages it did NOT report as failed. This prevents one bad message from blocking the entire batch (partial batch failure handling, the SQS-native equivalent of Kinesis's `bisect_on_function_error`).

**SQS queue policy for SNS delivery**
The analytics queue needs a resource policy allowing SNS to send to it. The queue policy uses `ArnLike` on the SNS topic ARN as a condition - this prevents any arbitrary SNS topic from delivering to this queue. The IAM identity policy on the SNS service principal is not sufficient; the queue must explicitly allow SNS delivery in a resource policy.

**Security group: egress only**
Lambda is not a server. No inbound traffic reaches it directly. The security group has no ingress rules. Egress is open (`-1`/all) so the function can reach AWS APIs (via VPC endpoints or NAT gateway), RDS, ElastiCache, and other services. In a production setup, scope egress to specific SG IDs and ports (RDS SG on 5432, ElastiCache SG on 6379, HTTPS on 443 via NAT).

**Memory sizing**
Dev: 256 MB (minimum viable, catches OOM early in dev). Staging: 512 MB (closer to production sizing, catches memory regressions before they hit prod). Adjust `memory_size` in the live config - no module change needed.

## Apply order

```
live/{env}/vpc/    # subnet IDs and VPC ID for Lambda VPC attachment
live/{env}/s3/     # bucket ARN and ID for S3 trigger
live/{env}/sqs/    # analytics queue is in this module, but main orders queue used by IAM policy
live/{env}/ssm/    # SSM parameter ARNs for IAM policy
live/{env}/lambda/ # depends on vpc, s3, sqs, ssm
```

## Handlers

**`handlers/orders_analytics.py`**
SQS consumer. Receives a batch of messages, each containing an SNS-wrapped `order.created` event. Unwraps the SNS envelope, logs the order ID. Returns `batchItemFailures` for any message that errors, leaving it in the queue for retry.

**`handlers/s3_processor.py`**
S3 trigger handler. Receives a batch of S3 event records, logs bucket name, key, and size for each object. Returns `batchItemFailures` for any record that errors.

## Ministack notes

- Lambda function creation applies cleanly
- Real Python 3.12 execution - functions actually run in Ministack
- `aws_sqs_queue_policy` applies cleanly
- `aws_lambda_event_source_mapping` applies cleanly with `function_response_types`
- `bisect_on_function_error` is Kinesis/DynamoDB stream-only - not valid on SQS event source mappings
- Security group descriptions must match EC2 API character restrictions - em dashes (`-`) not allowed, hyphens only
- VPC attachment applies (security group and subnet IDs accepted) but ENI creation is mocked

## Adding a new function

1. Add a handler file to `handlers/`
2. Add a `data "archive_file"` block pointing to the new handler
3. Add a `aws_lambda_function` resource referencing the archive
4. Wire triggers (event source mapping for SQS, permission + notification for S3, or leave triggerless for Scheduler invocation)
