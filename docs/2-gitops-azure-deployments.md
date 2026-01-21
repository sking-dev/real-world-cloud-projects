# Project 2: Adopting GitOps for Azure — From Click‑Ops to Pipeline‑Driven Deployments

⚙️ Draft version — content under review and subject to updates.

## Context

Historically, the organisation's infrastructure workloads were administered primarily by manual changes through various portals and UI experiences (AKA “Click‑Ops”).

This approach led to inconsistent configurations, limited traceability, and deployment drift across multiple environments.

The objective for the post-migration world was to modernize infrastructure delivery and governance by introducing GitOps practices — managing everything as code, deploying only through automated pipelines, and enforcing version control and peer review.

## Requirements

- All resource and configuration changes must originate from private Git repositories.  
- Standardize IaC (Infrastructure as Code) patterns across dev, test, and production environments.  
- Enable pull request–based approvals to improve accountability.  
- Standardise on Terraform as the primary IaC tool (following an initial false start with ARM templates), while maintaining Bicep examples for specific scenarios and future adoption where appropriate.  
- Integrate with Azure DevOps pipelines for CI/CD, artifact storage, and access control.  
- Provide predictable, auditable deployments and eliminate configuration drift.

## Architecture

- **Source of Truth:** Azure Repos repository storing Terraform modules and Bicep templates.  
- **CI/CD:** Azure Pipelines executing validation (linting, syntax checks) and deployment.  
- **State Management:**  
  - Terraform uses remote state via Azure Storage with state locking.  
  - Bicep deployments handled through ARM templates via pipeline tasks.  
- **Access Control:** Service connections for each environment with least privilege RBAC permissions.  
- **Policy enforcement (emerging):** Initial Azure Policy assignments at management‑group level, with the intent to bring policy definitions and assignments under IaC and GitOps control.
- **Logging and Monitoring:** Pipeline logs retained; deployments tracked via Azure Activity Logs.

## Key Decisions

- Adopted a modular IaC structure for shared network, security, and compute foundations, improving reuse and consistency across environments.
- Standardised on Visual Studio Code as a lightweight, flexible IDE for authoring and testing Terraform and Bicep.
- Chose Azure Pipelines for CI/CD to align with enterprise DevOps tooling.  
- Implemented required PR reviews, branch protections, and pipeline validations (`terraform validate`, `bicep build`).  
- Created a unified repository for Terraform and Bicep examples to compare patterns and maintain syntax equivalence, helping the team understand trade‑offs between the two approaches.
- Introduced naming and tagging standards enforced through templates.

## Operations

- Teams submit pull requests for any infrastructure changes; pipelines validate, plan, and apply automatically on approval.  
- Terraform state stored in remote Azure Storage with locking, and IaC definitions version‑controlled in Git, providing both safe state management and historical traceability of changes.
- Deployment results and change histories consolidated in Azure DevOps dashboards.  
- Azure Policy and custom governance scripts report compliance issues weekly.  
- Documentation stored in the codebase (README files and inline comments) plus an Azure DevOps project Wiki to simplify team onboarding and knowledge sharing.

## Future Enhancements

- Improve **static code analysis** in the build‑validation pipeline, strengthening linting and security checks before code is merged.​
- Evolve from static Terraform definitions for core services to **reusable modules** with environment‑specific variable files for dev, test, and production.​
- Enhance **pipeline quality gates** to encourage good PR hygiene and accountability, and to add safety nets for deployments to production environments (e.g. approvals, checks, and rollback options).

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project2-terraform/` — Terraform pipeline definitions and reusable module examples for shared infrastructure components
- `/code/project2-bicep/` — Bicep equivalents with parameterised deployments to illustrate native Azure IaC patterns
- `/docs/common/` — Shared standards, governance guidelines, and contribution practices for all infrastructure repositories
