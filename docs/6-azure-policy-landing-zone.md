# Project 6: Azure Policy Implementation for Landing Zone Governance

⚙️ Draft version — content under review and subject to refinement.

## Context

Following migration of IaaS workloads to a hub-and-spoke landing zone architecture, the environment consisted of a central connectivity subscription and a single spoke subscription hosting virtual machines and supporting services.

Without governance controls, resource tagging was inconsistent, diagnostic logging coverage was patchy, and VM SKUs differed widely, creating operational and cost-management risks.

This project implemented Azure Policy as the initial governance layer to standardise configurations, enforce security baselines, and provide compliance visibility across the landing zone without disrupting existing workloads or IaC processes.

## Requirements

- Audit and standardise tagging for cost allocation, ownership, and environment classification.
- Audit deployments against approved Azure regions for data residency and cost control.
- Audit high-risk configurations (public IPs, unencrypted storage, incorrect VM SKUs) before full enforcement.
- Deploy policies via Infrastructure as Code with pipeline automation for repeatability and auditability.
- Support management group hierarchy for future subscription scaling.
- **Maintain Terraform as single source of truth** - policies validate, never conflict with IaC.

## Architecture

- **Management Groups:** Root → Common → Platform/Landing Zone, providing policy inheritance to hub and spoke subscriptions.
- **Policy Initiatives:** Custom thematic initiatives using `[MyOrg]-[Scope]-[Theme]` naming convention for clarity and troubleshooting.
  - `[MyOrg]-Common-Baseline` (tagging audit, locations deny, naming audit)
  - `[MyOrg]-LandingZone-Workload` (VM sizing deny, storage encryption audit, PaaS compliance)
  - `[MyOrg]-Platform-Networking` (NSG flow logs audit, VNet peering deny, firewall policy audit)
  - `[MyOrg]-Common-Security` (Defender audit, auditing audit, encryption defaults deny)
  - `[MyOrg]-Common-Cost` (budget alerts audit, resource locks audit, auto-shutdown audit)
- **Policy Assignments:** Applied at appropriate management group scopes per initiative theme, with exemptions managed via IaC.
- **Deployment:** Terraform modules defining policy definitions, initiatives, and assignments, orchestrated via Azure Pipelines.
- **Reporting:** Azure Policy compliance dashboard integrated with Azure Monitor for remediation tracking.
- **Validation:** Test management group used to validate policy effects before production rollout.

## Key Decisions

- Used **audit + append effects initially** rather than DeployIfNotExists to avoid IaC drift conflicts with Terraform.
- **Terraform owns all configuration** (tags, diagnostics, encryption) as single source of truth - policies validate compliance only.
- Policy acts as **compliance guardrail** - blocks non-conformant deployments, never modifies existing resources.
- Aligned baseline policies to Microsoft Cloud Adoption Framework (CAF) landing zone guidance, using built-in initiatives where appropriate and supplementing with custom thematic initiatives using `[MyOrg]-[Scope]-[Theme]` naming convention.
- Chose **Terraform** over native Azure Policy APIs for policy management to maintain consistency with existing IaC patterns and enable multi-environment deployments.
- Scoped initial rollout to landing zone and platform management groups rather than root to limit blast radius during validation while establishing clear policy inheritance boundaries.

## Operations

- Deployed policy definitions and initiatives to test management group via Azure Pipelines with PR approval gates.
- Validated compliance across hub and spoke subscriptions, addressing 100% of non-compliant resources via Terraform updates or exemptions.
- Established weekly compliance reporting via Azure Monitor workbooks, shared with operations and security stakeholders.  
- Configured policy exemption requests as pull requests against the Terraform repository, maintaining governance audit trail.
- Documented remediation runbooks for common policy failures (tagging, VM sizing) for platform team self-service via Terraform updates.

## Future Enhancements

- Expand policy coverage to include Azure Defender plans and regulatory frameworks (e.g. ISO 27001).
- Implement custom policy definitions for workload-specific naming conventions and resource lock requirements.
- **Integrate policy compliance data with ServiceNow CMDB**: Automates remediation tickets when compliance drops below 95%, creating closed-loop governance between policy state and operational workflows.
- **Deploy Azure Blueprints** for self-service subscription provisioning: Embeds `[MyOrg]-Common-Baseline` initiative assignment in new landing zone subscriptions, ensuring Day 1 governance compliance.
- **Add budget alerts and cost management policies** linked to mandatory tagging: Configures £5k monthly warnings at landing zone scope, £50k at platform scope, driving financial accountability through existing tag data.

## Code References

Note: These references are placeholders and will be updated when the `/code` directory structure is finalised.

- `/code/project6-policy/terraform/` — Terraform modules for policy definitions, initiatives, and assignments.
- `/code/project6-policy/pipelines/` — Azure Pipelines YAML for policy deployment and validation.
- `/docs/common/` — Shared management group structure and governance standards.

## Appendix: Implementation Details

This section outlines the baseline management group structure and validation approach used for Azure Policy implementation.

### Management Group Structure and Deployment Flow

```text
Tenant Root Group
├─ mg-myorg-common                          # PROD: Tenant-wide baselines
├─ mg-myorg-common-test                     # TEST: Baseline + security validation
├─ mg-myorg-landing-zone                    # PROD FOCUS 1: Workload spokes + landing zone policies
│  └─ sub-myorg-spoke                       # Example spoke subscription (app/workload)
├─ mg-myorg-landing-zone-test               # TEST: Workload policies - no subs required
├─ my-myorg-platform                        # PROD FOCUS 2: Shared platform services
│  ├─ mg-myorg-connectivity                 # Hub networking + connectivity (hub-and-spoke)
│  │  └─ sub-myorg-hub                      # Hub subscription (shared VNet, firewall, etc.)
│  ├─ mg-myorg-aiservices
│  │  ├─ mg-myorg-aiservices-nonprod
│  │  └─ mg-myorg-aiservices-prod
│  ├─ mg-myorg-finance
│  │  ├─ mg-myorg-finance-nonprod
│  │  └─ mg-myorg-finance-prod
│  └─ mg-myorg-identity
│     ├─ mg-myorg-identity-nonprod
│     └─ mg-myorg-identity-prod
├─ my-myorg-platform-test                  # TEST: Platform networking policies - no subs required
└─ mg-myorg-root                           # Legacy staging / future expansion / sandbox
   ├─ mg-myorg-root-prod
   │  ├─ mg-myorg-root-prod-domains        # Business domain workloads
   │  └─ mg-myorg-root-prod-infrastructure # Supporting infra (monitoring, logging)
   └─ mg-myorg-root-nonprod
      ├─ mg-myorg-root-nonprod-domains
      └─ mg-myorg-root-nonprod-infrastructure
```

### Structure Rationale

- mg-myorg-landing-zone (Production):
  - Contains spoke subscription(s) hosting IaaS workloads
  - Scoped for [MyOrg]-LandingZone-Workload initiative ensuring workload-specific governance
  - Does not inherit platform networking/connectivity policies

- my-myorg-platform (Production):
  - Houses hub subscription (sub-myorg-hub) and shared services (AI, finance, identity)
  - Scoped for [MyOrg]-Platform-Networking initiative with stricter connectivity controls
  - Separates platform lifecycle from workload subscriptions

- mg-myorg-landing-zone-test (Validation):
  - Empty management group - no test subscriptions needed
  - Tests policy inheritance, assignment scoping, exemption handling, and compliance reporting
  - Pipeline DEV environment with PR approval gates before PROD rollout
  - Zero resource cost while validating real policy effects

### Deployment Flow

```text
1. Pipeline deploys to mg-test-landing-zone → Validate compliance reporting
2. PR approval → Deploy initiatives to mg-myorg-common, mg-myorg-landing-zone, my-myorg-platform
3. Monitor hub/spoke compliance via weekly Azure Monitor workbooks
4. Terraform plan/apply corrects non-compliance detected by audit policies
```

### Policy Structure Strategy

**Built-in vs Custom policies:**

- Built-in policies used for platform standards: security baselines (CIS, PCI-DSS), diagnostics settings audit, allowed locations/regions deny.
- Custom policies created for organisation-specific requirements: mandatory tagging audit (cost centre, owner, environment), approved VM SKU deny lists, naming conventions audit.

**Initiative design:**

- Custom thematic initiatives using [MyOrg]-[Scope]-[Theme] convention for instant readability
- Mix built-in + custom policies within each initiative for complete coverage
- Maximum 8-10 policies per initiative for focused compliance reporting and remediation
- Built-in initiatives considered for framework alignment (CIS, PCI-DSS) where appropriate

**Production initiatives deployed:**

```text
[MyOrg]-Common-Baseline        → mg-myorg-common      (audit + append tagging, deny locations)
[MyOrg]-LandingZone-Workload   → mg-myorg-landing-zone (deny VM SKU, audit storage encryption)  
[MyOrg]-Platform-Networking    → my-myorg-platform    (audit NSG flow logs, deny VNet peering)
[MyOrg]-Common-Security        → mg-myorg-common      (audit Defender, deny encryption defaults)
[MyOrg]-Common-Cost           → mg-myorg-common      (audit budget alerts, resource locks)
```

**Example [MyOrg]-Common-Baseline (9 policies):**

```text
1. Required tag: Environment (Dev/Test/Prod) → audit + append
2. Required tag: CostCentre → audit + append  
3. Required tag: Owner → audit + append
4. Location restriction: UK South + West Europe → deny
5. VM SKU allowlist → deny
6. Public IP restriction → deny
7. Diagnostic settings → audit (Terraform responsibility)
8. SQL Server auditing → audit
9. Resource naming convention → audit
```

**Policy effect strategy:**

```text
Day 1: audit + append (tagging visibility), deny (locations, VM SKU, public IP)
Phase 2: audit → deny progression (storage encryption, NSG rules)
Future: modify (only after full IaC coverage for diagnostics, advanced configs)

**Rationale**: Audit + append provides compliance visibility without IaC conflicts. 
Deny effects block non-conformant deployments at creation time. Terraform remains 
source of truth for all resource configuration.
```

### IaC Tooling Choices

**Terraform selected over Bicep** despite Bicep's Azure-native advantages because:

- Team competency - existing Terraform patterns reduced training overhead
- Collaboration - remote state backend with locking for multiple contributors
- Pipeline maturity - established Azure DevOps YAML workflows with PR approval gates
- Lifecycle coverage - azurerm_policy_* resources handle definitions → assignments → exemptions → remediation

**Bicep considered as future option** to leverage native ARM integration, pre-flight policy validation, and simplified state management.

Deployment flow:

```text
Terraform plan → mg-test-landing-zone → Validate compliance → PR approval → 
mg-myorg-common + mg-myorg-landing-zone + my-myorg-platform → Monitor drift
```
