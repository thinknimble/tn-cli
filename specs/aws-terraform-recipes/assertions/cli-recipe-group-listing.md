---
id: cli-recipe-group-listing
parent: aws-terraform-recipes
created: 2026-07-20T23:00:00Z
priority: 1
status: done
depends-on: cli-script-recipes
branch: feature/aws-pipeline

---

# Recipe Group: All 7 Recipes Appear Under `[aws-terraform]` in `tn --list`

## What Must Be True

All seven AWS Terraform recipes (the VPC recipe plus the six extracted script recipes) are grouped under an `[aws-terraform]` section header in the justfile, and appear as a cohesive group in `tn --list` output.

## Success Criteria

- `tn --list` output includes an `[aws-terraform]` group header
- The following 7 recipes appear under that group:
  - `aws-setup-vpc`
  - `aws-ecs-exec`
  - `aws-stream-logs`
  - `aws-tf-setup-backend`
  - `aws-tf-init-backend`
  - `aws-setup-oidc`
  - `aws-setup-secrets`
- No AWS Terraform recipes appear outside the `[aws-terraform]` group
- Group ordering is logical: VPC first, then backend setup, then OIDC/secrets, then operational tools (ecs-exec, stream-logs)
