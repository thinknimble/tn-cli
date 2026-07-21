---
id: oidc-role-per-project-per-env
parent: oidc-per-project-isolation
created: 2026-07-21T22:00:00Z
priority: 2
status: done
branch: feature/aws-pipeline
---

# OIDC Role Is Per-Project-Per-Environment

## What Must Be True

`aws-setup-oidc` accepts a required `service` parameter and creates a role named `github-actions-<service>-<environment>` (e.g., `github-actions-my-project-development`). Each project gets its own isolated role.

## Context

Currently the role is named `github-actions-<environment>` with no project scoping. The `service` parameter does not exist — all projects in an account share the same role.

## Success Criteria

- `aws-setup-oidc` signature includes a required `service` parameter (no default, errors if omitted)
- Role name follows pattern `github-actions-<service>-<environment>`
- Policy names follow pattern `github-actions-<service>-<environment>-deployment-policy` and `github-actions-<service>-<environment>-secrets-access`
- Command output prints the full role ARN for the user to copy into `environments.json`
- Existing roles without service prefix are not affected (command only manages roles matching the new naming pattern)
