# modules/s3

Hardened S3 bucket: versioning, server-side encryption, Block Public Access, bucket policy, lifecycle, and optional access logging.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_s3_bucket` | The bucket |
| `aws_s3_bucket_versioning` | Every write creates a new version - deletes are reversible |
| `aws_s3_bucket_server_side_encryption_configuration` | Encryption at rest (SSE-S3 or SSE-KMS) |
| `aws_s3_bucket_public_access_block` | Four settings that block all public access |
| `aws_s3_bucket_policy` | Deny HTTP, deny unencrypted uploads, optional role scoping |
| `aws_s3_bucket_lifecycle_configuration` | Tier to IA/Glacier, expire old versions |
| `aws_s3_bucket_logging` | Access logs to a separate bucket (optional) |

## Security layers

**Versioning**
Every PUT creates a new version. Every DELETE creates a delete marker - the object is not gone. Protects against accidental deletes, bad deploys overwriting data, and ransomware. Cost implication: old versions are billed at the same rate - use `noncurrent_version_expiration_days` to control growth.

**Encryption at rest**

| | SSE-S3 | SSE-KMS |
|---|---|---|
| Key management | AWS managed | Customer managed |
| Decrypt audit trail | None | CloudTrail log per decrypt |
| Extra cost | Free | ~$0.03/10k API calls |
| Use when | Default workloads | HIPAA/PCI/SOX or cross-account data |

**Block Public Access (all 4 settings)**
Safety net on top of IAM. `BlockPublicAcls` and `IgnorePublicAcls` prevent ACL-based exposure. `BlockPublicPolicy` rejects bucket policies that grant public access. `RestrictPublicBuckets` enforces this even if a public policy somehow gets applied. All 4 on by default.

**Bucket policy: deny HTTP**
`aws:SecureTransport = false` → Deny. Forces all traffic over TLS. Without this, data can be read in transit on the same network.

**Bucket policy: deny unencrypted uploads**
`s3:x-amz-server-side-encryption` header missing → Deny on `PutObject`. Prevents a misconfigured client from uploading plaintext even though the bucket default encryption is set. The `depends_on` on the public access block resource is required - AWS rejects bucket policies before the block is in place.

**Conditional role scoping**
When `allowed_role_arns` is provided, two additional statements are added: allow the listed ARNs, deny all other principals. This is a resource policy that works alongside IAM - both must allow.

**Bucket policy: Terraform type system note**
The conditional statements use `concat()` + `for _ in (condition ? [1] : []) : { statement }` instead of a ternary with `flatten()`. Terraform type-checks ternary branches at plan time - a two-element tuple and an empty tuple are different types and will fail. The `for` expression always produces a `list(object)` of consistent type regardless of branch.

## Lifecycle tiers

```
Day 0   - STANDARD      (full price, low latency)
Day 30  - STANDARD_IA   (~40% cheaper, per-retrieval fee)
Day 90  - GLACIER        (~80% cheaper, 3-5h restore)
Day 365 - expire (deleted)
```

Non-current versions expire after 30 days. Adjust thresholds to match actual access patterns.

## Ministack notes

- Versioning, lifecycle, Block Public Access, and bucket policy all work identically to real AWS
- SSE-KMS: accepted by Ministack but not real key material - valid for practicing the Terraform pattern
- `allowed_role_arns` scoping works; the Deny principal condition evaluates correctly
- CloudFront, Transfer Acceleration, Storage Lens, and cross-region replication are not available
