# modules/sqs

Standard SQS queue with a dead letter queue, redrive policy, and optional resource-based access policy.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_sqs_queue` - `*-<name>-dlq` | Dead letter queue — receives messages after N failed processing attempts |
| `aws_sqs_queue` - `*-<name>` | Main queue — producers publish here, consumers poll here |
| `aws_sqs_queue_redrive_allow_policy` | Declares on the DLQ which source queues may use it |
| `aws_sqs_queue_policy` | Resource-based policy scoping send/receive to specific IAM principals (conditional) |

## Key concepts

**Visibility timeout**
When a consumer receives a message, SQS locks it for `visibility_timeout_seconds`. The consumer must delete it before the timeout expires or SQS makes it visible again for re-delivery. Set this to at least your maximum expected processing time — too short causes duplicate delivery, too long delays re-processing after a crash.

**Long polling (`receive_wait_time_seconds`)**
Short polling (value = 0) returns immediately even if the queue is empty, burning API calls and cost at high frequency. Long polling (1-20s) waits up to N seconds for a message before returning an empty response. Default is 20 (maximum). Always use long polling unless you have a specific reason not to.

**Dead letter queue + redrive policy**
After a message fails `max_receive_count` times (consumer receives it but never deletes it), SQS automatically moves it to the DLQ. The DLQ holds failed messages for inspection — longer retention than the main queue. This separates poison messages from healthy ones so one bad message cannot block the whole queue.

**`aws_sqs_queue_redrive_allow_policy`**
The DLQ side of the redrive configuration. Declares which source queues are allowed to use this queue as their DLQ. Using `redrivePermission = byQueue` with an explicit `sourceQueueArns` list prevents any arbitrary queue from dumping into this DLQ.

**Standard vs FIFO**
Standard queues: at-least-once delivery, best-effort ordering, up to 120,000 messages/s throughput. FIFO queues: exactly-once processing, strict ordering per message group, up to 3,000 messages/s. FIFO names must end in `.fifo` — the module handles this automatically when `fifo_queue = true`.

**Resource policy vs identity policy**
The queue policy (`aws_sqs_queue_policy`) is a resource-based policy — it controls who can access the queue from the queue's side. IAM identity policies on roles/users control access from the principal's side. For internal queues in the same account, identity policies alone are sufficient — the queue policy is optional. For cross-account access, a queue resource policy is required.

## Architecture

```
Producer (ECS task / Lambda / CI)
    │
    │  sqs:SendMessage
    ▼
┌─────────────────────────────────────┐
│  platform-zero-{env}-orders         │  visibility_timeout: 30s
│                                     │  long polling: 20s
│  Consumer receives → processes      │
│  If deleted: done ✓                 │
│  If not deleted within 30s:         │
│    → visible again (re-delivery)    │
│  After 3 failures:                  │
└──────────────┬──────────────────────┘
               │ redrive (maxReceiveCount: 3)
               ▼
┌─────────────────────────────────────┐
│  platform-zero-{env}-orders-dlq     │  retention: 14 days
│                                     │  manual inspection / replay
└─────────────────────────────────────┘
```

## Apply order

```
live/{env}/iam/   # apply first (IAM roles needed for queue policy)
live/{env}/sqs/   # depends on iam (uses ci_deploy_role_arn in queue policy)
```

## Ministack notes

- Standard queues and DLQs apply cleanly
- `aws_sqs_queue_redrive_allow_policy` is supported
- `aws_sqs_queue_policy` is supported
- FIFO queues are supported but not tested in this lab

## Adding a new queue

Add a new `live/{env}/sqs-<name>/terragrunt.hcl` pointing to this module with a different `queue_name`. Each queue gets its own DLQ automatically. Wire `allowed_sender_arns` and `allowed_consumer_arns` to the IAM role ARNs of the services that need access.
