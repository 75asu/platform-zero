# modules/gcs

Cloud Storage bucket with uniform bucket-level access, versioning, lifecycle rules, and IAM bindings. GCP equivalent of awslab/s3.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_storage_bucket` | The bucket — versioning, lifecycle, location, storage class |
| `google_storage_bucket_iam_member` | Per-principal IAM bindings on the bucket |

## Key concepts

**Uniform bucket-level access**
When enabled, GCP ignores object-level ACLs and enforces IAM only. Required for new workloads — the legacy ACL model is deprecated. All access is controlled via `google_storage_bucket_iam_member`.

**Cross-cloud comparison: S3 vs GCS**
S3 uses bucket policies (JSON resource policies) + IAM identity policies. GCS uses bucket-level IAM bindings — the same model as the rest of GCP. No separate "bucket policy" concept. Object ACLs are the GCS equivalent of S3 object-level permissions, but uniform access disables them.

**Storage class and lifecycle**
`STANDARD` → `NEARLINE` (30+ day old objects, access once/month) → `COLDLINE` (90+ days, once/quarter) → `ARCHIVE` (365+ days, once/year). Lifecycle rules automate the transition and eventual deletion. Cost decreases as class increases; retrieval cost increases.

**`force_destroy`**
GCS refuses to delete a non-empty bucket. `force_destroy = true` tells Terraform to delete all objects first. Safe for lab. Set false in prod — an accidental `terraform destroy` cannot wipe production data.

**Location**
Multi-region (`US`, `EU`, `ASIA`): redundant across regions, slightly more expensive, higher read throughput. Single-region (`us-central1`): lower latency to co-located compute, lower cost, no cross-region redundancy. Match to where Cloud Run / GKE is deployed.

## Apply order

```
live/{env}/iam/    # service account emails needed for iam_members
live/{env}/gcs/    # depends on iam
```

## MiniSky notes

- `google_storage_bucket` applies cleanly
- `google_storage_bucket_iam_member` applies cleanly
- Lifecycle rules are accepted by the API
- Versioning configuration applies
- `force_destroy` behaviour is identical — MiniSky respects it
- Bucket URL (`gs://...`) is returned in outputs
