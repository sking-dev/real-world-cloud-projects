# Project 6: Azure Policy Implementation for Landing Zone Governance

⚙️ Draft version — content under review and subject to refinement.

## Context

Following migration of IaaS workloads to a hub‑and‑spoke landing zone architecture, the environment consisted of a central connectivity subscription and a single spoke subscription hosting virtual machines and supporting services.

Without governance controls, resource tagging was inconsistent, diagnostic logging coverage was patchy, and VM SKUs differed widely, creating operational and cost‑management risks.

This project implemented Azure Policy as the initial governance layer to standardise configurations, enforce security baselines, and provide compliance visibility across the landing zone without disrupting existing workloads.

## Requirements

- Audit and standardise tagging for cost allocation, ownership, and environment classification.
- Audit deployments against approved Azure regions for data residency and cost control.
- Audit and enable diagnostic settings on critical resources (VMs, VNets, Key Vault) for security and operations monitoring.  
- Audit high‑risk configurations (public IPs, unencrypted storage) before full enforcement.
- Deploy policies via Infrastructure as Code with pipeline automation for repeatability and auditability.
- Support management group hierarchy for future subscription scaling.

## Architecture

- **Management Groups:** Root → Platform → Landing Zone, providing policy inheritance to hub and spoke subscriptions.
- **Policy Initiatives:** Custom baseline initiative grouping tagging, location, diagnostics, and security policies.
  - TODO: Confirm the naming convention used for the custom initiatives.
    - `MyOrg-Baseline-Security` (CIS controls, encryption)
    - `MyOrg-Baseline-Tagging` (cost centre, owner, environment)  
    - `MyOrg-Platform-Diagnostics` (VMs, VNets, Key Vault)
- **Policy Assignments:** Applied at Landing Zone management group scope, with exemptions managed via IaC.
- **Deployment:** Terraform modules defining policy definitions, initiatives, and assignments, orchestrated via Azure Pipelines.
- **Reporting:** Azure Policy compliance dashboard integrated with Azure Monitor for remediation tracking.
- **Validation:** Test management group used to validate policy effects before production rollout.

## Key Decisions

- Maintained audit effect initially to build stakeholder confidence before controlled transition to enforce where appropriate.  
- Aligned baseline policies to Microsoft Cloud Adoption Framework (CAF) landing zone guidance, using built‑in initiatives where appropriate and supplementing with custom tagging policies.
- Chose **Terraform** over native Azure Policy APIs for policy management to maintain consistency with existing IaC patterns and enable multi‑environment deployments.
- Implemented **DeployIfNotExists** policies for diagnostics rather than deny policies to proactively configure resources while allowing manual override where justified.  
- Scoped initial rollout to landing zone management group rather than root to limit blast radius during validation.

## Operations

- Deployed policy definitions and initiatives to test management group via Azure Pipelines with PR approval gates.
- Validated compliance across hub and spoke subscriptions, addressing 100% of non‑compliant resources via automated remediation or exemptions.
- Established weekly compliance reporting via Azure Monitor workbooks, shared with operations and security stakeholders.  
- Configured policy exemption requests as pull requests against the Terraform repository, maintaining governance audit trail.
- Documented remediation runbooks for common policy failures (tagging, diagnostics) for platform team self‑service.

## Future Enhancements

- Expand policy coverage to include Azure Defender plans and regulatory frameworks (e.g. ISO 27001).
- Implement custom policy definitions for workload‑specific naming conventions and resource lock requirements.
- Integrate policy compliance data with ServiceNow CMDB for automated ticket generation on drift detection.
- Deploy Azure Blueprints for self‑service subscription provisioning with pre‑baked policy assignments.
- Add budget alerts and cost management policies linked to mandatory tagging for financial governance.

## Code References

Note: These references are placeholders and will be updated when the `/code` directory structure is finalised.

- `/code/project6-policy/terraform/` — Terraform modules for policy definitions, initiatives, and assignments.
- `/code/project6-policy/pipelines/` — Azure Pipelines YAML for policy deployment and validation.
- `/docs/common/` — Shared management group structure and governance standards.

## Appendix: Implementation Details

This section outlines the baseline management group structure and validation approach used for Azure Policy implementation.

### Management Group Structure and Deployment Flow

```text
Root (tenant root group)
├── Platform
├── mg-landing-zone      # PROD: Contains hub connectivity + spoke workload subscriptions
└── mg-test-landing-zone # TEST: Empty MG for policy validation (no subscriptions required)
```

### Structure Rationale

**mg-landing-zone (Production):**

- Contains both **hub connectivity subscription** and **spoke subscription(s)** hosting IaaS workloads
- Single policy assignment scope ensures consistent governance inheritance
- Standard "platform/foundation" naming aligns with landing zone patterns

**mg-test-landing-zone (Validation):**

- **Empty management group** - no test subscriptions needed
- Tests policy inheritance, assignment scoping, exemption handling, and compliance reporting
- Pipeline DEV environment with PR approval gates before PROD rollout
- Zero resource cost while validating real policy effects

### Deployment Flow

```text
1. Pipeline deploys to mg-test-landing-zone → Validate compliance reporting
2. PR approval → Deploy to mg-landing-zone → Monitor hub/spoke compliance
3. Weekly Azure Monitor workbooks track ongoing compliance drift
```

This structure supports the scalable hub-and-spoke pattern while maintaining governance discipline from Day One.

## Policy Structure Strategy

**Built-in vs Custom policies:**

- **Built-in policies** used for platform standards: security baselines (CIS, PCI-DSS), diagnostics settings, allowed locations/regions.
- **Custom policies** created for organisation-specific requirements: mandatory tagging (cost centre, owner, environment), approved VM SKU allowlists, naming conventions.
- **Initiative design:**
  - **Custom thematic initiatives** (`MyOrg-Baseline-Security`, `MyOrg-Baseline-Tagging`, and so forth)
  - **Mix built-in + custom policies** within each initiative for complete coverage
  - Maximum 5-8 policies per initiative for focused compliance reporting and remediation
  - Built-in initiatives considered for framework alignment (CIS, PCI-DSS) where appropriate

```text
Good practice pattern (example of)

- MyOrg-Baseline-Security
- MyOrg-Baseline-Tagging  
- MyOrg-Platform-Diagnostics
- MyOrg-Workloads-VMs
- MyOrg-Cost-Management
```

**Policy effect strategy:**

```text
Day 1: audit + DeployIfNotExists (diagnostics, tagging)
Phase 2: enforce (location, basic security)
Future: deny (high-risk SKUs, public access)
```

## IaC Tooling Choices

**Terraform selected over Bicep** despite Bicep's Azure-native advantages because:

- **Team competency** - existing Terraform patterns reduced training overhead
- **Collaboration** - remote state backend with locking for multiple contributors  
- **Pipeline maturity** - established Azure DevOps YAML workflows with PR approval gates
- **Lifecycle coverage** - `azurerm_policy_*` resources handle definitions → assignments → exemptions → remediation

**Bicep considered as future option** to leverage native ARM integration, pre-flight policy validation, and simplified state management.

**Deployment flow:**

```text
Terraform plan → mg-test-landing-zone → Validate compliance → PR approval → mg-landing-zone → Monitor drift
```
