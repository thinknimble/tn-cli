---
id: oidc-per-project-isolation
created: 2026-07-21T22:00:00Z
priority: 2
---

# OIDC Per-Project Isolation

## Problem

`aws-setup-oidc` creates one IAM role per environment (`github-actions-development`) shared across all projects in an AWS account. The deployment policy grants `Resource: "*"` access to ECR, ECS, RDS, S3, IAM, and more. Any project's GitHub Actions pipeline can access every other project's resources in the same account.

Each new project deployed on the shared role increases the migration cost when isolation is eventually needed (e.g., multi-customer dashboard).

## Desired State

Each project gets its own OIDC role (`github-actions-<service>-<environment>`) with a trust policy scoped to the specific GitHub repo. This prevents cross-project resource access and cross-repo role assumption.

## Scope

This spec covers the tn-cli justfile changes. The template-side changes (environments.json, post-gen instructions) are tracked in `tn-spa-bootstrapper` under the same spec ID.

## Constraints

- Must be backwards-compatible: existing shared roles should still work until migrated
- Role naming must follow `github-actions-<service>-<environment>` convention
- `<service>` must match the `sanitized_tf_service_name` / `SERVICE_NAME` used elsewhere
