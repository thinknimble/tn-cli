---
id: aws-terraform-recipes
created: 2026-07-20T23:00:00Z
priority: 1
---

# AWS Terraform Recipes

## Problem

The tn-spa-bootstrapper template bundles one-time setup scripts (VPC creation, OIDC setup, backend initialization, secrets bucket, etc.) inside each generated project. These scripts contain no project-specific logic but are trapped inside the cookiecutter template, wrapped in `{% raw %}` / `{% endraw %}` jinja guards, and duplicated across every project that uses the template.

Worse, the VPC creation logic lives inside per-project Terraform state, causing a race condition: multiple projects sharing a VPC can collide during concurrent `terraform apply` runs because each project believes it owns the VPC lifecycle.

## Solution

Extract all generic AWS infrastructure scripts into `tn-cli` as reusable justfile recipes under an `[aws-terraform]` group. Each recipe accepts parameters (project name, environment, region, profile) instead of relying on cookiecutter template variables.

The key architectural change: VPC creation becomes a one-time `tn aws-setup-vpc` command run before any project deploys, rather than a conditional resource inside each project's Terraform. This eliminates the shared-state race condition entirely.

## Recipes

Seven recipes total:

1. **`aws-setup-vpc`** -- Idempotent shared VPC creation with tagged resources
2. **`aws-ecs-exec`** -- Interactive ECS container exec session
3. **`aws-stream-logs`** -- CloudWatch log streaming
4. **`aws-tf-setup-backend`** -- S3 + DynamoDB backend creation
5. **`aws-tf-init-backend`** -- Terraform backend initialization
6. **`aws-setup-oidc`** -- GitHub OIDC role provisioning
7. **`aws-setup-secrets`** -- S3 secrets bucket creation

## Constraints

- Recipes must be pure shell -- no cookiecutter, no jinja
- All recipes must be idempotent (safe to run multiple times)
- Tag naming conventions must match the Terraform data source filters in the bootstrapper template
- Recipes appear under an `[aws-terraform]` group in `tn --list` output
