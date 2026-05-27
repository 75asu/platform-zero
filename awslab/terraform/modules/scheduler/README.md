# modules/scheduler

EventBridge Scheduler for time-based Lambda invocations. Replaces managing a cron container. Schedules are defined as a map - add or remove schedules by editing the live config, no module changes needed.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_scheduler_schedule_group` | Logical container for related schedules; enables group-level IAM and tagging |
| `aws_iam_role` - `scheduler` | Execution role assumed by the Scheduler service to invoke targets |
| `aws_iam_role_policy` - `scheduler_invoke` | Grants `lambda:InvokeFunction` on all target function ARNs |
| `aws_scheduler_schedule` (per schedule) | One schedule per entry in `var.schedules` - cron or rate expression, target function, payload |

## Key concepts

**Schedule groups**
All schedules in this module land in a dedicated group (`platform-zero-{env}`). The default group exists in every account. Custom groups enable:
- Listing all schedules for an environment without filtering by name prefix
- Deleting all schedules in an environment by deleting the group
- Separate IAM conditions scoped to a group

**Cron vs rate expressions**
Two expression types, both in UTC by default:

```
cron(0 2 * * ? *)   # every day at 02:00 UTC
rate(1 hour)         # every 60 minutes from first invocation
```

Cron: precise control over day, time, and day-of-week. Requires `?` in either the day-of-month or day-of-week field (not both). Rate: simple interval. Does not guarantee alignment to clock boundaries - a `rate(1 hour)` schedule created at 14:37 fires at 15:37, 16:37, etc.

**Flexible time window**
`mode = "OFF"` - the schedule fires exactly at the specified time. `mode = "FLEXIBLE"` with `maximum_window_in_minutes` allows Scheduler to fire within a window around the target time. Useful for reducing load spikes when many schedules fire simultaneously.

**IAM execution role**
The Scheduler service needs permission to invoke the Lambda target. The execution role is assumed by `scheduler.amazonaws.com` and granted `lambda:InvokeFunction` on each target function ARN. This follows the same pattern as EventBridge Rules with Lambda targets.

**Payload injection**
Each schedule injects a JSON payload into the Lambda invocation:

```hcl
payload = { mode = "nightly-cleanup" }
```

The module merges `{ source = "scheduler", schedule = "<schedule-key>" }` with the user-provided payload. This lets the Lambda function identify which schedule triggered it and behave accordingly.

**Retry policy**
`maximum_retry_attempts` controls how many times Scheduler retries a failed invocation (Lambda returns an error or times out). `max_event_age_seconds` controls how long Scheduler holds onto a scheduled invocation before dropping it if the target is unavailable. Default: 2 retries, 1 hour max age. Staging uses 3 retries to catch transient failures in a staging-like environment.

## Apply order

```
live/{env}/lambda/    # function ARNs needed for IAM policy and schedule target
live/{env}/scheduler/ # depends on lambda
```

## Defining schedules

Schedules are a map in the live config. Each entry becomes one `aws_scheduler_schedule` resource:

```hcl
schedules = {
  nightly-cleanup = {
    expression = "cron(0 2 * * ? *)"
    lambda_arn = dependency.lambda.outputs.orders_analytics_arn
    payload    = { mode = "nightly-cleanup" }
  }
  hourly-metrics = {
    expression = "rate(1 hour)"
    lambda_arn = dependency.lambda.outputs.orders_analytics_arn
    payload    = { mode = "aggregate" }
  }
}
```

To add a schedule: add a key to the map. To remove: delete the key. No module changes needed.

## Ministack notes

- `aws_scheduler_schedule_group` applies cleanly
- `aws_scheduler_schedule` with cron and rate expressions applies cleanly
- `ListScheduleGroups` and `ListSchedules` both return correct results
- IAM role and policy apply cleanly
- Schedules do not actually fire in Ministack - the trigger mechanism is mocked
