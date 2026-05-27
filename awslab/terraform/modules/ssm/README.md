# modules/ssm

SSM Parameter Store for runtime configuration. String parameters for non-secret values, SecureString for sensitive values that don't warrant Secrets Manager rotation.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_ssm_parameter` - `string.*` | Plaintext runtime config - feature flags, endpoints, tuning knobs |
| `aws_ssm_parameter` - `secure.*` | KMS-encrypted config - internal API keys, webhook tokens |

## Key concepts

**String vs SecureString**
String parameters are stored and returned in plaintext. Use them for non-sensitive config: feature flags, Redis endpoints, max connection counts, ARNs that need to be readable without IAM KMS permissions.

SecureString parameters are encrypted at rest using KMS. The caller needs both `ssm:GetParameter` and `kms:Decrypt`. Use them for secrets that change infrequently and don't need automatic rotation - internal API keys, webhook signing secrets. For credentials that rotate (database passwords, OAuth tokens), use Secrets Manager instead.

**Path structure**
Parameters follow the path convention `/{project}/{environment}/{category}/{key}`. The path hierarchy enables IAM scoping: a role can be granted `ssm:GetParameter` on `arn:aws:ssm:*:*:parameter/platform-zero/dev/*` and gets nothing outside dev. The path also enables `GetParametersByPath` - one API call retrieves all parameters under a prefix.

**ECS consumption pattern**
ECS task definitions read SSM values via the `secrets` block:

```hcl
secrets = [
  {
    name      = "INTERNAL_API_KEY"
    valueFrom = "arn:aws:ssm:us-east-1:123:parameter/platform-zero/dev/config/internal-api-key"
  }
]
```

The ECS agent resolves the ARN and injects the decrypted value as an environment variable before the container starts. The task execution role needs `ssm:GetParameters` and `kms:Decrypt` on the relevant key.

**`nonsensitive()` on for_each**
Terraform refuses to use a sensitive variable as a `for_each` argument because the keys would appear as resource instance identifiers in state. The parameter keys (paths like `config/internal-api-key`) are not themselves secret - only the values are. `nonsensitive()` tells Terraform it is safe to expose the keys as resource IDs while the values remain sensitive inside each resource.

**KMS key**
`key_id` is left empty in this module - Ministack uses a default key. In real AWS, pass `var.kms_key_id` from the KMS module to encrypt with a CMK. The CMK enables cross-account access, audit logging in CloudTrail, and automatic rotation.

## Apply order

```
live/{env}/kms/  # KMS key ARN for SecureString encryption
live/{env}/ssm/  # depends on kms
```

## Ministack notes

- String and SecureString parameters both apply cleanly
- `GetParametersByPath`, `GetParameter`, and `GetParameters` all work
- KMS encryption is mocked - SecureString values are stored but not truly encrypted
- `nonsensitive()` wrapper required on `secure_parameters` - Terraform rejects sensitive maps as for_each arguments (keys would appear as resource IDs in state)
