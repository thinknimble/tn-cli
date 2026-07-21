---
id: cli-vpc-recipe
parent: aws-terraform-recipes
created: 2026-07-20T23:00:00Z
priority: 1
status: done
branch: feature/aws-pipeline
---

# VPC Recipe: `aws-setup-vpc` Idempotently Creates a Tagged Shared VPC

## What Must Be True

The `tn-cli` justfile contains an `aws-setup-vpc` recipe that creates (or confirms existence of) a shared VPC with all required networking resources, tagged with a naming convention that Terraform data sources can filter on deterministically.

## Success Criteria

- Recipe exists in the justfile with parameters for `vpc_name` (default: `tn-shared`), `environment` (default: `dev`), `profile` (default: `default`), and `region` (default: `us-east-1`)
- Running the recipe twice produces no changes on the second run (idempotent)
- Created resources and their tags:
  - VPC: Name tag `{vpc_name}-{environment}` (e.g., `tn-shared-dev`)
  - Internet Gateway: Name tag `{vpc_name}-{environment}-igw`
  - Route Table: Name tag `{vpc_name}-{environment}-rt`
  - Subnets: at least 2 across different AZs, Name tags include `{vpc_name}-{environment}`
- No `{% raw %}` / `{% endraw %}` jinja guards in the recipe code
- No cookiecutter template variables (`{{cookiecutter.*}}`) in the recipe code
- Tag naming convention matches the filters used by `data "aws_vpc"`, `data "aws_internet_gateway"`, and `data "aws_route_table"` data sources in the bootstrapper's Terraform

## Cross-Repo Dependency

The bootstrapper repo's `tf-mandatory-vpc-data-sources` assertion depends on this recipe's tag naming convention. The data source filters in `main.tf` must match the tags this recipe creates.
