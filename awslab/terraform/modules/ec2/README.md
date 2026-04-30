# modules/ec2

Hardened EC2 instance: SSM-only access, IMDSv2, encrypted root volume, instance profile with least-privilege IAM, no public IP. Also validates the distributed IAM pattern introduced in this repo.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_iam_role` - `*-ec2-instance` | Instance identity — trust: `ec2.amazonaws.com` |
| `aws_iam_policy` - `*-ec2-instance-policy` | SSM session, CloudWatch logs/metrics, SSM parameter read |
| `aws_iam_role_policy_attachment` | Attaches policy to role |
| `aws_iam_instance_profile` - `*-ec2-instance-profile` | Wrapper EC2 requires to carry an IAM role |
| `aws_security_group` - `*-ec2-instance` | No inbound rules, allow all egress |
| `aws_instance` | AL2023 instance with all hardening applied |

IAM resources always apply. `aws_instance` and `aws_security_group` are conditional (`create_instance` variable) to handle environments where the provider doesn't fully support EC2.

## Best practices implemented

**No SSH / SSM Session Manager only**
No key pair, no port 22. The SSM agent on the instance opens an outbound HTTPS connection to the SSM service. You get a shell via the AWS console or `aws ssm start-session`. Eliminates bastion hosts, key rotation, and the attack surface of an open port.

**IMDSv2 (Instance Metadata Service v2)**
`http_tokens = "required"` forces a PUT request to get a session token before credentials are served from `169.254.169.254`. IMDSv1 is vulnerable to SSRF - any HTTP client in the VM can steal credentials with a simple GET. This is the pattern from the Capital One breach (2019). IMDSv2 blocks that path.

**Instance profile (not instance role)**
EC2 cannot attach an IAM role directly. The instance profile is a container for the role - it is what `iam_instance_profile` on `aws_instance` accepts. The SDKs running on the instance query the metadata service to get temporary credentials from the profile automatically.

**Least-privilege IAM policy**
Four scoped statements:
- SSM Session Manager: 9 specific actions, `Resource = "*"` (SSM requires this - no ARN scoping available)
- CloudWatch Logs: 4 log actions scoped to `/aws/ec2/<project>-<env>` log group only
- CloudWatch Metrics: `PutMetricData` scoped by namespace condition to `CWAgent` and project namespaces
- SSM Parameter Store: GetParameter scoped to `/<project>/<env>/*` path only

**No public IP**
`associate_public_ip_address = false`. Instances are not reachable from the internet. SSM session manager works via outbound HTTPS — no public IP needed.

**Encrypted root volume**
`encrypted = true` on `root_block_device`. Protects data at rest if an EBS snapshot is copied or a volume is detached. Uses the default EBS KMS key.

**Hardened security group**
No inbound rules. Zero open ports. Egress allows all (required for SSM, CloudWatch, yum/dnf, HTTPS). Inbound traffic is not possible regardless of network topology.

**CloudWatch agent bootstrap via user_data**
On first boot: installs `amazon-cloudwatch-agent`, pulls the agent config from SSM Parameter Store (`/<project>/<env>/cloudwatch-agent-config`), and ensures `amazon-ssm-agent` is running. AL2023 ships with SSM agent pre-installed.

**AL2023 AMI via data source**
`data "aws_ami"` with `most_recent = true` and the `al2023-ami-*-x86_64` name filter. Always picks the latest patched Amazon Linux 2023 image. Override with `ami_id_override` when the data source is not available.

## Distributed IAM pattern

IAM for this module lives in `iam.tf` within this module directory - not in `modules/iam/`. The central IAM module provides the permission boundary ARN as an output. The live config wires it in:

```hcl
dependency "iam" { config_path = "../iam" }

inputs = {
  permission_boundary_arn = dependency.iam.outputs.permission_boundary_arn
}
```

This avoids circular dependencies: if the central IAM module created the EC2 role, it would need the instance's resource ARNs; the instance would need the role ARN. Distributed ownership breaks the cycle cleanly.

## Ministack notes

- `create_instance = false`: Ministack's EC2 emulation doesn't fully support `aws_instance` creation. IAM resources (role, policy, attachment, instance profile) still apply and validate the pattern.
- `permission_boundary_arn = ""`: Ministack doesn't implement `PutRolePermissionsBoundary`. Set to empty string; the module skips the boundary when the variable is empty.
- `ami_id_override = "ami-12345678"`: Ministack has no real AMI catalog. The data source is skipped when an override is provided.
- `enable_imdsv2 = false` and `encrypt_root_volume = false`: Ministack doesn't support `metadata_options` or EBS encryption. Both default to `true` for real AWS.
- VPC/subnet data sources use `count = var.create_instance && var.vpc_id == ""` — they are not evaluated when `create_instance = false`, which avoids errors in accounts with no default VPC.
