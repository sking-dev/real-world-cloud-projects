# Project 2: Adopting GitOps for Azure — From Click‑Ops to Pipeline‑Driven Deployments

⚙️ Draft version — content under review and subject to updates.

## Context

The existing Azure environment relied heavily on manual changes through the portal (“Click‑Ops”). This approach led to inconsistent configurations, limited traceability, and deployment drift across multiple subscriptions. The objective was to modernize infrastructure delivery and governance by introducing GitOps practices — managing everything as code, deploying only through automated pipelines, and enforcing version control and peer review.

## Requirements

- All resource and configuration changes must originate from Git repositories.  
- Standardize IaC (Infrastructure as Code) patterns across dev, test, and production environments.  
- Enable pull request–based approvals to improve accountability.  
- Support both Terraform and Bicep templates, to suit team preferences and skill sets.  
- Integrate with Azure DevOps pipelines for CI/CD, artifact storage, and access control.  
- Provide predictable, auditable deployments and eliminate configuration drift.

## Architecture

- **Source of Truth:** GitHub repository storing Terraform modules and Bicep templates.  
- **CI/CD:** Azure Pipelines executing validation (linting, syntax checks) and deployment.  
- **State Management:**  
  - Terraform uses remote state via Azure Storage with state locking.  
  - Bicep deployments handled through ARM templates via pipeline tasks.  
- **Access Control:** Service connections for each environment with limited RBAC permissions.  
- **Policy Enforcement:** Azure Policy applied at management‑group level to ensure consistent compliance.  
- **Logging and Monitoring:** Pipeline logs retained; deployments tracked via Azure Activity Logs.

## Key Decisions

- Adopted modular IaC structure for shared network, security, and compute foundations.  
- Chose Azure Pipelines for CI/CD to align with enterprise DevOps tooling.  
- Implemented required PR reviews, branch protections, and pipeline validations (`terraform validate`, `bicep build`).  
- Created a unified repository for Terraform and Bicep examples to compare patterns and syntax equivalence.  
- Introduced naming and tagging standards enforced through templates.

## Operations

- Teams submit pull requests for any infrastructure changes; pipelines validate, plan, and apply automatically on approval.  
- Terraform state stored in version‑controlled storage to ensure historical traceability.  
- Deployment results and change histories consolidated in Azure DevOps dashboards.  
- Azure Policy and custom governance scripts report compliance issues weekly.  
- Documentation stored in `/docs/common/` to simplify team onboarding.

## Future Enhancements

- Evaluate GitOps controllers such as Flux v2 or Argo CD for continuous reconciliation of Kubernetes deployments.  
- Implement policy testing pre‑commit using tools like Open Policy Agent (OPA) or Checkov.  
- Extend GitOps framework to cover hybrid deployments and multi‑cloud orchestration.  
- Explore use of GitHub Actions for cross‑platform pipeline parity.

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project2-terraform/` — Terraform pipeline definitions and reusable module examples.  
- `/code/project2-bicep/` — Bicep equivalents with parameterized deployments.  
- `/docs/common/` — Shared standards, governance, and contribution guides.
