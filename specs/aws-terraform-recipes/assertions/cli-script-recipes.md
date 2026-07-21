---
id: cli-script-recipes
parent: aws-terraform-recipes
created: 2026-07-20T23:00:00Z
priority: 1
status: done
branch: feature/aws-pipeline
---

# Script Recipes: Six Extracted Operations Exist as tn-cli Recipes

## What Must Be True

The `tn-cli` justfile contains six recipes extracted from the bootstrapper template's scripts. Each recipe accepts parameters instead of relying on cookiecutter template variables, and contains no jinja template syntax.

## Recipes

| Recipe Name | Extracted From |
|---|---|
| `aws-ecs-exec` | `terraform/scripts/ecs-exec.sh` |
| `aws-stream-logs` | `terraform/scripts/stream-logs.sh` |
| `aws-tf-setup-backend` | `terraform/scripts/setup_backend.sh` |
| `aws-tf-init-backend` | `terraform/scripts/init_backend.sh` |
| `aws-setup-oidc` | `terraform/scripts/setup-github-oidc-role.sh` |
| `aws-setup-secrets` | `.github/scripts/setup-secrets-bucket.sh` |

## Success Criteria

- All 6 recipes exist in the justfile
- No `{% raw %}` / `{% endraw %}` jinja guards remain in any recipe code
- No cookiecutter template variables (`{{cookiecutter.*}}`) appear in any recipe
- Each recipe accepts project-specific values as parameters (e.g., project name, environment, region, profile) rather than hardcoded or template-derived values
- Each recipe is idempotent (safe to run multiple times without side effects)

## Cross-Repo Dependency

The bootstrapper repo's `template-extracted-scripts-removed` assertion depends on these recipes existing before the corresponding scripts are removed from the template.
