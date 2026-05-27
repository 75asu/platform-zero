# modules/cloudfront

CloudFront distribution supporting dual origins (S3 via OAC and ALB), managed cache/request/response-header policies, optional WAF attachment, geo-restriction, and access logging.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_cloudfront_origin_access_control` | OAC for secure S3 origin access (replaces legacy OAI) |
| `aws_cloudfront_distribution` | The distribution — cache behaviours, origins, SSL, WAF |

## Key concepts

**Origin Access Control (OAC)**
OAC signs requests from CloudFront to S3 using SigV4. S3 rejects unsigned requests, so the bucket never needs public access. OAC supports SSE-KMS encrypted buckets (OAI did not) and all HTTP methods. The bucket policy is wired in the S3 module — it must allow `cloudfront.amazonaws.com` as principal and validate `aws:SourceArn` to this distribution's ARN.

**Dual origin: S3 + ALB**
When `alb_origin_dns` is set, the ALB becomes the primary origin (dynamic content). S3 becomes a secondary origin for assets, with path-pattern cache behaviours routing `/static/*` and similar prefixes to it. When only `s3_origin_bucket` is set (ALB null), S3 is the sole origin — typical for static sites or SPAs.

**Managed policies**
AWS maintains named cache and origin request policies. Using managed IDs avoids managing TTL and header-forwarding configuration by hand. Common IDs used in this repo:
- Cache: `658327ea` — CachingOptimized (sensible defaults, no query strings)
- Origin request: `216adef6` — AllViewer (forwards all headers, useful for ALB origins)
- Response headers: `67f7725c` — SecurityHeadersPolicy (HSTS, X-Frame-Options, CSP)

**WAF integration**
Pass `waf_web_acl_arn` from the WAF module output. The WAF web ACL must have `scope = CLOUDFRONT` (not REGIONAL — CloudFront WAFs must be in `us-east-1`). Evaluated before CloudFront serves from cache.

**Price classes**
CloudFront has edge locations worldwide. Price class controls which edges serve requests:
- `PriceClass_100` — North America and Europe only (cheapest, good for most SaaS)
- `PriceClass_200` — Adds Asia Pacific and Middle East
- `PriceClass_All` — All edges globally (most expensive)

**Custom error responses**
Map HTTP error codes (e.g., 404) to S3 objects (e.g., `/404.html`). Useful for SPAs where the app router handles 404s — return `200` with `index.html` so the browser executes the JS bundle and lets the SPA render the correct error state.

## Apply order

```
live/{env}/s3/          # bucket exists before OAC policy needs ARN
live/{env}/waf/         # web_acl_arn wired into this module
live/{env}/cloudfront/  # distribution last — references S3, WAF, ALB
live/{env}/route53/     # alias record pointing to distribution_domain_name
```

## Ministack notes

- `aws_cloudfront_distribution` is supported in Ministack — the distribution is created and queryable
- CloudFront `domain_name` returned is a Ministack placeholder (not a real CDN endpoint)
- S3 OAC + bucket policy flow works within Ministack's S3 implementation
- WAF attachment is accepted without enforcement in Ministack
- SSL/ACM: Ministack accepts `acm_certificate_arn = null` (uses CloudFront default certificate)
- Route53 alias records pointing at `distribution_hosted_zone_id` resolve within Ministack
