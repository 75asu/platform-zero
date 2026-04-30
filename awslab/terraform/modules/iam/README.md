# modules/iam

Account-level IAM: permission boundary, GitHub OIDC provider, CI deploy role, cross-account role.
Service IAM (EC2 role, ECS task role, etc.) lives in each service module - not here.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_iam_policy` - `*-platform-boundary` | Permission boundary: ceiling on all roles in the account |
| `aws_iam_openid_connect_provider` - GitHub | OIDC federation for GitHub Actions - no stored IAM keys |
| `aws_iam_role` - `*-ci-deploy` | Role GitHub Actions assumes to run Terraform |
| `aws_iam_role` - `*-cross-account` | Cross-account access (conditional - skipped when not configured) |

## Architecture: distributed IAM pattern

Roles and policies are defined in the module that uses them, not centrally here.

```
modules/iam/         - account-level: boundary, OIDC, CI role
modules/ec2/iam.tf   - EC2 instance role, policy, profile
modules/ecs/iam.tf   - ECS execution role, task role  (when built)
modules/rds/iam.tf   - RDS access role                (when built)
```

Why: central IAM creates circular dependencies (IAM needs the bucket ARN, S3 needs the role ARN). Distributed pattern lets each module own its IAM lifecycle. The boundary still applies to all roles - it is passed as an input variable.

## Key concepts

**Permission boundary**
Applied to every role in every service module. Even if a role has `AdministratorAccess` attached, the boundary blocks anything not explicitly listed. Platform team controls the boundary; service teams control their role policies within it. IAM evaluation order: Explicit Deny > SCP > Permission Boundary > Identity Policy > Resource Policy.

**OIDC federation (GitHub Actions)**
GitHub generates a JWT per workflow run. STS verifies the JWT against the registered provider and issues temporary credentials. No IAM user, no access key, nothing to rotate or leak. The trust policy conditions (`token.actions.githubusercontent.com:sub`) scope the role to specific repos and branches.

**CI deploy role**
Scoped permissions for Terraform: S3 read/write (state), DynamoDB read/write (lock), and deploy permissions scoped by environment tag. Not admin. If CI is compromised, blast radius is limited to what Terraform needs.

**Cross-account access + confused deputy protection**
When a role is assumed from another AWS account, a third party could trick a shared service into assuming your role using your role ARN. `sts:ExternalId` in the trust policy acts as a shared secret - only your system passes it, so the trusted service can verify the request is actually from you.

**Trust policy vs permission policy**
Trust policy = who can assume the role (`sts:AssumeRole`). Permission policy = what actions the role can take. Getting the trust policy wrong is how privilege escalation happens - an overly broad principal means anyone can assume the role.

## Apply order

```
live/dev/iam/      # apply first
live/dev/s3/       # no dependency on iam (iam outputs not needed)
live/dev/ec2/      # depends on iam for permission_boundary_arn
```

`dependency "iam"` in a service's `terragrunt.hcl` is only needed if the service consumes an IAM module output (e.g. `permission_boundary_arn`). The ec2 module takes the boundary ARN as an input variable and the live config wires it up.

## Adding a new service

1. Create `modules/<service>/iam.tf` with the role, policy, and profile for that service
2. Wire `permission_boundary_arn` from the IAM module output via the live config
3. The service module outputs its role ARN so other modules (S3 bucket policy, etc.) can scope access to it

## Ministack notes

- `enable_permission_boundary = false` in live configs: Ministack does not implement `PutRolePermissionsBoundary`
- OIDC provider and CI role apply cleanly
- Cross-account role skipped when `cross_account_trusted_account_id` is not set
