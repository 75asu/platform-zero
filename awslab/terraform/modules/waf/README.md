# modules/waf

WAFv2 web ACL with AWS Managed Rule Sets, IP-based allow/block lists, rate limiting, geo-blocking, and optional CloudWatch logging.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_wafv2_ip_set.this` | Named IP address collections for use in rules |
| `aws_wafv2_rule_group.this` | Custom reusable rule groups (optional) |
| `aws_wafv2_web_acl.this` | The web ACL — all rules evaluated in priority order |
| `aws_wafv2_web_acl_association` | Associates the ACL with an ALB (when `alb_arn` is set) |
| `aws_cloudwatch_log_group.waf` | Log destination for WAF decisions (conditional) |
| `aws_wafv2_web_acl_logging_configuration` | Routes WAF logs to CloudWatch (conditional) |

## Key concepts

**Scope**
WAF ACLs have two scopes that cannot be changed after creation:
- `CLOUDFRONT` — attached to a CloudFront distribution, must be created in `us-east-1`
- `REGIONAL` — attached to ALBs, API Gateway, AppSync, in the resource's region

This module defaults to `REGIONAL`. For CloudFront, pass `scope = "CLOUDFRONT"` and ensure the provider is `us-east-1`.

**Rule priority**
Rules are evaluated lowest-priority-number first. The first matching rule's action applies — subsequent rules are skipped. Priority ordering in this module (lowest = evaluated first):
1. IP allow list (if configured) — bypasses all other rules for trusted IPs
2. IP block list — blocks known-bad IPs before they hit managed rules
3. Geo-block — blocks by country code
4. Rate limit — throttles excessive requests per IP
5. Managed: AWSManagedRulesKnownBadInputsRuleSet
6. Managed: AWSManagedRulesAdminProtectionRuleSet
7. Managed: AWSManagedRulesCoreRuleSet (OWASP Top 10)
8. Custom rule groups (if configured)

**AWS Managed Rule Sets**
Pre-built rules maintained by AWS threat intelligence. Updated automatically without Terraform changes. Each rule set consumes WAF Capacity Units (WCUs) — the per-ACL limit is 1500 WCUs. Monitor `aws_wafv2_web_acl.this.capacity` output.
- `AWSManagedRulesCoreRuleSet`: OWASP Top 10 — SQLi, XSS, LFI, RFI, command injection
- `AWSManagedRulesAdminProtectionRuleSet`: blocks access to `/admin`, `/wp-admin`, etc.
- `AWSManagedRulesKnownBadInputsRuleSet`: known-malicious request patterns

**IP sets**
Define `ip_sets` as a map of named CIDR lists. Reference a set by key in `ip_block_list_key` or `ip_allow_list_key`. This separates the IP list management (update CIDRs in one place) from the rule logic (just reference the key).

**Rate limiting**
Set `rate_limit` to the maximum number of requests allowed per 5-minute window per IP. Requests exceeding the limit receive a 429 response. Tune per environment — dev can be generous; prod should be tuned to expected legitimate traffic peaks.

**Default action**
`allow` — all requests pass unless a rule blocks them. Use `block` only when you are certain the allow list and managed rules are complete (rare; causes false positives at launch).

## Architecture

```
Request
  │
  ▼
WAF web ACL
  │
  ├─ IP allow? → ALLOW (skip rest)
  ├─ IP block? → BLOCK
  ├─ Geo block? → BLOCK
  ├─ Rate limit exceeded? → BLOCK
  ├─ Known bad input? → BLOCK
  ├─ Admin path? → BLOCK
  ├─ OWASP match? → BLOCK
  └─ Default: ALLOW
  │
  ▼
ALB / CloudFront
```

## Apply order

```
live/{env}/waf/          # standalone — no module dependencies
live/{env}/cloudfront/   # references web_acl_arn output (CLOUDFRONT scope)
# ALB module (future) references web_acl_arn output (REGIONAL scope)
```

## Ministack notes

- `aws_wafv2_web_acl` creates and returns a valid ARN in Ministack
- Rules are accepted by the API but WAF enforcement does not actually filter traffic
- Logging configuration is accepted — CloudWatch log group is created but WAF does not write real log entries
- `aws_wafv2_web_acl_association` with an ALB ARN is supported in Ministack
- Use Ministack WAF to validate the Terraform config is correct before deploying to real AWS

## Connecting WAF to CloudFront vs ALB

One WAF ACL cannot be shared between CloudFront and ALB — they require different scopes. The typical pattern is two ACL deployments:

```
# CLOUDFRONT scope (us-east-1 provider)
live/{env}/waf-cloudfront/    → waf_web_acl_arn → cloudfront module

# REGIONAL scope (same region as ALB)
live/{env}/waf/               → waf_web_acl_arn → alb module
```

In this repo, the single WAF module in `live/{env}/waf/` is REGIONAL scope and wired to the ALB. CloudFront WAF is left as a future addition when an ACM certificate is provisioned.
