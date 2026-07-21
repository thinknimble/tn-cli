---
id: deploy-policy-resource-scoped
parent: oidc-per-project-isolation
created: 2026-07-21T22:00:00Z
priority: 2
status: draft
---

# Deployment Policy Resources Are Scoped to Project

## What Must Be True

The OIDC role's deployment policy restricts resource access to the project's own resources using the `<service>` naming convention, rather than granting `Resource: "*"` across the account.

## Context

Current policy grants `ecr:*`, `ecs:*`, `rds:*`, `s3:*`, `iam:*`, etc. on `Resource: "*"`. Any project's pipeline can access every other project's ECR repos, ECS services, RDS instances, and S3 buckets.

This is the complex assertion — deferred until per-project roles and repo-scoped trust are in place. Resource scoping can be tightened via policy updates without migration.

## Success Criteria

- ECR access scoped to `arn:aws:ecr:<region>:<account>:repository/<service>-*`
- ECS access scoped to the project's cluster and services (`<service>-*` prefix)
- RDS access scoped to `arn:aws:rds:<region>:<account>:db:<service>-*` and related sub-resources
- S3 access scoped to project-specific buckets (`<service>-terraform-state`, `<service>-terraform-secrets`)
- Secrets Manager access scoped to `arn:aws:secretsmanager:<region>:<account>:secret:<service>-*`
- CloudWatch Logs scoped to `arn:aws:logs:<region>:<account>:log-group:/ecs/<service>-*`
- IAM access scoped to roles/policies with `<service>-*` prefix
- Shared read-only resources (VPC describe, ACM list, Route53 read) can remain `Resource: "*"`
