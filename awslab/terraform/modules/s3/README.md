# modules/s3

## Design decisions

### Why 7 separate resources instead of one big block?

Each hardening layer is a separate Terraform resource (`aws_s3_bucket_versioning`, `aws_s3_bucket_policy`, etc.). AWS split these from the monolithic `aws_s3_bucket` resource in provider v4. The separation means each layer can be changed or removed independently without recreating the bucket. Recreating an S3 bucket in prod means losing all objects.

### Versioning

Every PUT creates a new version. Every DELETE creates a delete marker - the object is not gone. This protects against accidental deletes, bad deploys overwriting data, and ransomware (you can restore to any prior version).

Cost implication: every version is billed at the same rate as current objects. The lifecycle rule for `noncurrent_version_expiration_days` keeps this from growing unbounded.

### Encryption: SSE-S3 vs SSE-KMS

Both use AES-256. The difference is key control and audit trail:

| | SSE-S3 | SSE-KMS |
|---|---|---|
| Key management | AWS manages | You manage (via KMS) |
| Audit trail | None | CloudTrail logs every decrypt |
| Cost | Free | ~$0.03/10k API calls |
| Access control | Bucket IAM only | IAM + KMS key policy (two gates) |
| Compliance fit | Most workloads | HIPAA/PCI/SOX/FedRAMP |

Default is SSE-S3. Use SSE-KMS when: compliance requires an audit trail of who decrypted what, you need key rotation on a defined schedule, or data crosses account boundaries and you need a second access gate.

### Block Public Access (all 4 settings)

These are a safety net on top of IAM. They block accidental public exposure even if a bucket policy is misconfigured.

- `BlockPublicAcls` - rejects any PUT that grants a public ACL
- `IgnorePublicAcls` - ignores existing public ACLs even if present
- `BlockPublicPolicy` - rejects bucket policies that grant public access
- `RestrictPublicBuckets` - enforces restriction even if a public policy slips through

All 4 on unless explicitly serving a public static website.

### Bucket policy: deny HTTP + deny unencrypted uploads

Two statements that should be on every prod bucket:

**Deny HTTP** (`aws:SecureTransport = false` → Deny): forces all traffic over TLS. Without this, someone on the same network can read data in transit.

**Deny unencrypted uploads** (`s3:x-amz-server-side-encryption is null` → Deny on PutObject): prevents anyone from uploading an object that bypasses server-side encryption. Without this, a misconfigured client can store plaintext even though the bucket default encryption is set.

`depends_on` the public access block resource because AWS rejects bucket policies before the block is in place.

### Lifecycle rules

Without lifecycle rules, S3 costs grow unbounded. The default tier progression:

```
Day 0   → STANDARD         (low latency, full price)
Day 30  → STANDARD_IA      (infrequent access, ~40% cheaper, per-retrieval fee)
Day 90  → GLACIER           (archive, ~80% cheaper, 3-5h restore time)
Day 365 → expire (deleted)
```

Non-current versions expire after 30 days - controls version bloat when versioning is enabled.

Adjust the day thresholds based on access patterns. If data is never accessed after 7 days, start the IA transition at 7 not 30.

### Server access logging

Every GET/PUT/DELETE is logged to a separate bucket. The logging bucket should not log itself (circular logging). In prod: ship these logs to a WORM bucket or SIEM for tamper-evident audit trail.

Disabled by default in this module (set `logging_target_bucket` to enable) because it requires a pre-existing logging bucket. Build that as a separate module first, then wire it in.

### Tags

Every resource is tagged with `Environment`, `Project`, and `ManagedBy = terraform`. Tags are how you: attribute costs by team/project in Cost Explorer, apply SCPs in AWS Organizations, and filter resources during incident response.

---

## Ministack notes

This module is tested against [Ministack](https://ministack.dev), a local AWS API emulator. Most features work identically. Known gaps:

- KMS encryption: the `aws:kms` algorithm is accepted but the key is not real - fine for practicing the Terraform pattern
- CloudFront, Transfer Acceleration, Storage Lens, Replication: not available in Ministack

Everything else (versioning, lifecycle, logging, Block Public Access, bucket policy) runs identically to real AWS.
