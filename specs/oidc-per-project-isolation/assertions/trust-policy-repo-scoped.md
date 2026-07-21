---
id: trust-policy-repo-scoped
parent: oidc-per-project-isolation
created: 2026-07-21T22:00:00Z
priority: 2
status: done
branch: feature/aws-pipeline
---

# Trust Policy Is Scoped to Specific GitHub Repo

## What Must Be True

The OIDC role's trust policy allows assumption only from the specific GitHub repository, not the entire GitHub organization.

## Context

Currently the trust policy condition uses `repo:<github_org>/*:*` which allows any repo in the org to assume the role. For per-project isolation, only the project's repo should be able to assume its role.

## Success Criteria

- `aws-setup-oidc` accepts a `repo` parameter (or derives it from `service` with a convention like `<github_org>/<service>`)
- Trust policy `StringLike` condition uses `repo:<github_org>/<repo_name>:*` instead of `repo:<github_org>/*:*`
- When updating an existing role's trust policy, new repo conditions are appended without removing existing ones (idempotent, additive)
- Command output confirms which repo was added to the trust policy
