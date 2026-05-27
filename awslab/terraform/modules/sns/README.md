# modules/sns

SNS topic with SQS fan-out subscriptions. One publish from a producer reaches multiple downstream consumers without the producer knowing who they are.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_sns_topic` | The pub/sub topic - producers send here |
| `aws_sns_topic_policy` | Resource policy granting publish rights to specific IAM principals; grants SNS service principal to deliver to SQS |
| `aws_sns_topic_subscription` (per subscriber) | Wires each SQS queue as a subscriber - one resource per queue ARN in `sqs_subscriber_arns` |

## Key concepts

**Fan-out pattern**
A producer (ECS task, Lambda, CI pipeline) publishes one message to the SNS topic. SNS delivers a copy to every subscriber simultaneously. This decouples the producer from all consumers: adding a new consumer requires zero changes to the producer. Removing a consumer requires zero changes to any other component.


**SQS subscription vs raw message delivery**
By default (`raw_message_delivery = false`) SNS wraps the original message in an envelope:

```json
{
  "Type": "Notification",
  "MessageId": "...",
  "TopicArn": "...",
  "Message": "{\"event\":\"order.created\",\"orderId\":\"abc123\"}",
  "Timestamp": "..."
}
```

The Lambda or SQS consumer must unwrap the envelope to get the original payload. Set `raw_message_delivery = true` to skip the envelope and deliver the original message body directly. Useful when the consumer is not SNS-aware.

**Why two IAM grants are needed**
The SNS topic policy needs two separate grants:
1. `sns:Publish` for the IAM principals that are allowed to publish (ECS task role, CI deploy role). This is an identity grant - these principals also need the permission in their identity policy.
2. `sqs:SendMessage` for the SNS service principal (`sns.amazonaws.com`) to deliver messages to each SQS subscriber queue. Without this, SNS can accept the message but cannot deliver it - messages silently drop.

The SQS queue policy (on the subscriber queue) must also allow SNS to send. This module does not manage the subscriber queue policies - those are in the SQS/Lambda modules that own each queue.

**Circular dependency handling**
SNS needs the Lambda analytics queue ARN to subscribe it. Lambda needs the SNS topic ARN in its SQS queue policy (to allow SNS delivery). This is a circular dependency: SNS -> Lambda -> SNS.

Resolution: Lambda applies first and creates the analytics queue. The SNS topic ARN is known in advance (it follows a deterministic naming pattern), so the Lambda live config hardcodes it rather than taking it as a `dependency` output. SNS applies second and subscribes the queue.

## Apply order

```
live/{env}/sqs/     # orders queue ARN for subscription
live/{env}/lambda/  # analytics queue ARN for subscription
live/{env}/iam/     # ECS task role ARN for publisher grant
live/{env}/sns/     # depends on all three
```

## Ministack notes

- `aws_sns_topic` applies cleanly
- `aws_sns_topic_policy` applies cleanly
- `aws_sns_topic_subscription` with SQS protocol applies cleanly
- `ListTopics`, `GetTopicAttributes`, `ListSubscriptionsByTopic` all work
- Message delivery to SQS subscribers works end to end in Ministack
