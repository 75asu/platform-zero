# modules/pubsub

Pub/Sub topic with a pull subscription, dead letter topic, DLQ pull subscription, and IAM bindings for publisher and subscriber service accounts. GCP equivalent of awslab/sns + sqs combined.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_pubsub_topic` - main | The topic producers publish to |
| `google_pubsub_topic` - dlq | Dead letter topic for messages that exceed max_delivery_attempts |
| `google_pubsub_subscription` - pull | Pull subscription — consumer polls on its own schedule |
| `google_pubsub_subscription` - dlq_pull | Pull subscription on the DLQ for inspection and replay |
| `google_pubsub_topic_iam_member` | Grants publisher service account `roles/pubsub.publisher` |
| `google_pubsub_subscription_iam_member` | Grants subscriber service account `roles/pubsub.subscriber` |

## Key concepts

**Cross-cloud comparison: SQS + SNS vs Pub/Sub**
AWS splits messaging into two services: SQS (pull queue, one consumer) and SNS (fan-out, multiple subscribers). GCP Pub/Sub combines both. One topic, multiple subscriptions — each subscription independently receives every message. Pull subscriptions behave like SQS. Push subscriptions (not in this module) behave like SNS delivering to HTTP endpoints.

**Pull vs push subscriptions**
Pull: consumer polls `subscriptions.pull` API, processes messages, calls `acknowledge`. Controlled by the consumer. Push: Pub/Sub delivers to an HTTPS endpoint you configure. The endpoint must respond 2xx within the ack deadline. Push is simpler for Cloud Run or Cloud Functions (no polling loop needed).

**Ack deadline**
How long the consumer has to ack a message before Pub/Sub re-delivers it to another subscriber. Match to your maximum processing time. Too short: duplicate deliveries. Too long: failed messages block slower reprocessing.

**Dead letter policy**
After `max_delivery_attempts` failures (consumer receives but never acks), Pub/Sub moves the message to the dead letter topic. Pub/Sub uses a Pub/Sub service account to do this — that SA needs `pubsub.subscriber` on the source subscription and `pubsub.publisher` on the DLQ topic. In the lab, MiniSky does not enforce this; in real GCP, you must grant those permissions.

**Message retention**
Pub/Sub retains undelivered messages for up to 7 days (604800s). After that, they are dropped permanently. `message_retention_duration` on the subscription overrides the topic default.

## Apply order

```
live/{env}/iam/     # publisher and subscriber service account emails
live/{env}/pubsub/  # depends on iam
```

## MiniSky notes

- `google_pubsub_topic` applies cleanly
- `google_pubsub_subscription` with `dead_letter_policy` applies cleanly
- `ListTopics`, `ListSubscriptions` both return correct results
- Message delivery is supported in MiniSky
- DLQ service account IAM grants are not enforced (skip for lab)
