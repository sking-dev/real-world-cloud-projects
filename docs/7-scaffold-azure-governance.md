# Project 6: Scaffolding Governance in Azure

⚙️ **Draft version — content under review and subject to refinement.**

## Context

Hub‑and‑spoke landing zone architectures require **stable, version‑controlled management group (MG) hierarchies** to support policy inheritance, RBAC scoping, budget alerts, and Defender controls at scale.

Manual management group creation via the **Azure portal** lacks version control, repeatability, and auditability — making it fragile for enterprise‑scale subscription growth.

This project defines the management group hierarchy as **Infrastructure as Code (IaC)** from day one, using the dedicated `myorg-azuregovernance` repository. It establishes a **reusable governance control plane** and foundation for all future policy and security assets.

## Requirements

- Define complete management group hierarchy matching the target landing zone design (Common → Platform → Landing Zone → Domains).  
- Support **test**, **non‑prod**, and **prod** governance environments with **isolated Terraform state**.  
- Enable policy, RBAC, budget, and Defender modules to consume management group IDs as inputs.  
- Deploy via **Azure Pipelines** with PR approval gates and progressive promotion (test → non‑prod → prod).  
- **Maintain Terraform as the single source of truth** for all governance scaffolding.  
- Ensure **Test** environment requires zero subscriptions and validates only structure and wiring.

## Architecture

- **Repository:** Dedicated `myorg-azuregovernance` repository owns all governance IaC, separate from `myorg-landing-zone` and `myorg-shared`.  
- **Management Groups:** Full hierarchy created via `azurerm_management_group` resources with a narrow, function‑first top level:
  - `mg-myorg-common` → `mg-myorg-common-prod`, `mg-myorg-common-nonprod`
  - `mg-myorg-platform` → `mg-myorg-platform-test`, `mg-myorg-platform-nonprod`, `mg-myorg-platform-prod`
  - `mg-myorg-landing-zone` → `mg-myorg-landing-zone-test`, `mg-myorg-landing-zone-nonprod`, `mg-myorg-landing-zone-prod`
- **Environment roles:**
  - **Test:** Empty MGs (`*-test`) used only for IaC and pipeline validation (no subscriptions).  
  - **Non‑Prod:** `*-nonprod` MGs for dev/stage workloads with relaxed policies and lower‑tier SKUs.  
  - **Prod:** `*-prod` MGs for production workloads with stricter policies, higher‑tier SKUs, and compliance guardrails.  
- **Hub / spoke placement:**
  - Hub connectivity subscription (prod) under `mg-myorg-platform-prod` (for shared networking / connectivity services).  
  - Optional non‑prod hub connectivity subscription(s) under `mg-myorg-platform-nonprod`.  
  - Spoke landing zone subscriptions under `mg-myorg-landing-zone-nonprod` and `mg-myorg-landing-zone-prod` respectively.  
- **Environments:** Separate Terraform directories for `test`, `nonprod`, and `prod` under `/environments/`, each with its own backend and state file (`mg-test.tfstate`, `mg-nonprod.tfstate`, `mg-prod.tfstate`).  
- **Modules:** Reusable `modules/management-groups/` builds the MG trees based on HCL data structures (e.g. maps/lists describing parents, children, and display names).  
- **Pipelines:** Azure DevOps YAML pipelines orchestrate deployments with gated promotion: `test → nonprod → prod`, with manual approvals between stages.  
- **Outputs:** MG IDs and related metadata published to remote state for consumption by `myorg-landing-zone` and `myorg-shared` repositories.  

## Key Decisions

- **Greenfield baseline:** Deploy the MG hierarchy via IaC before any policies or workloads, creating a stable governance foundation.  
- **Dedicated governance repo:** Centralises IaC for management groups, policies, RBAC, budgets, and Defender — decoupled from delivery repositories.  
- **Three‑tier environment structure:** Introduce a dedicated **Test** hierarchy for IaC validation alongside functional **Non‑Prod** and **Prod** environments for real workloads.  
- **Terraform‑native:** Use `azurerm_management_group` resources directly to maintain parity with landing zone patterns.  
- **State isolation:** Dedicated state files (`mg-test.tfstate`, `mg-nonprod.tfstate`, `mg-prod.tfstate`) allow independent lifecycle control.  
- **Validation strategy:** Test hierarchy validates IaC, module wiring, and pipeline flow with zero resource cost before promotion.

## Operations

- Deployed empty Test management group hierarchy through Azure Pipelines with PR approval.  
- Validated Terraform outputs and remote state publication.  
- Promoted changes to Non‑Prod and Prod via gated pipelines.  
- Documented management group naming conventions and change process as PRs within `myorg-azuregovernance`.  
- Verified production subscriptions (`sub-myorg-hub`, `sub-myorg-spoke`) correctly assigned to Prod management groups.

## Future Enhancements

- Deploy Azure Policy initiatives and assignments after management group scaffolding (see Project 7).  
- Add `modules/rbac/` for management group and subscription‑level role assignments.  
- Implement `modules/budgets/` for proactive cost management.  
- Introduce `modules/blueprints/` or template specs for self‑service landing zone creation.  
- Add `modules/defender/` for Defender for Cloud controls scoped to Platform and Landing Zone management groups.  

## Code References

*Paths to be finalised once repository structure is stabilised.*

- `/code/myorg-azuregovernance/environments/test/` — Test MG hierarchy (empty validation environment).  
- `/code/myorg-azuregovernance/environments/nonprod/` — Non‑prod MG hierarchy with relaxed guardrails and non‑prod subscriptions.  
- `/code/myorg-azuregovernance/environments/prod/` — Prod MG hierarchy with policy enforcement and live subscriptions.  
- `/code/myorg-azuregovernance/modules/management-groups/` — Reusable Terraform MG module.  
- `/code/myorg-azuregovernance/pipelines/01-mg-hierarchy.yml` — Azure Pipelines YAML for management group deployment flow.  
- `/code/myorg-azuregovernance/vars/mg-hierarchy.tfvars` — MG tree definition.  

## Appendix: Implementation Details

### Management Group Hierarchy

```text
Tenant Root Group
├─ mg-myorg-common
│  ├─ mg-myorg-common-prod            # PROD: Org-wide prod baselines
│  └─ mg-myorg-common-nonprod         # NONPROD: Org-wide non-prod baselines
├─ mg-myorg-platform
│  ├─ mg-myorg-platform-test          # TEST: Empty IaC validation scope
│  ├─ mg-myorg-platform-nonprod       # NONPROD: Shared services (non-prod)
│  └─ mg-myorg-platform-prod          # PROD: Shared services (prod)
│     └─ sub-myorg-hub-connectivity   # Hub connectivity subscription (prod)
└─ mg-myorg-landing-zone
   ├─ mg-myorg-landing-zone-test      # TEST: Empty IaC validation scope
   ├─ mg-myorg-landing-zone-nonprod   # NONPROD: Spoke landing zones
   │  └─ sub-myorg-spoke-*-nonprod    # Non-prod workload subscriptions
   └─ mg-myorg-landing-zone-prod      # PROD: Spoke landing zones
      └─ sub-myorg-spoke-*-prod       # Prod workload subscriptions
```

### Repository Structure

```text
myorg-azuregovernance/
├── environments/
│   ├── test/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf          # mg-test.tfstate
│   ├── nonprod/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf          # mg-nonprod.tfstate
│   └── prod/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── backend.tf          # mg-prod.tfstate
├── modules/
│   └── management-groups/      # azurerm_management_group resources + data model
├── policies/
│   ├── definitions/
│   └── initiatives/
├── pipelines/
│   ├── 01-mg-hierarchy.yml
│   ├── 02-governance.yml       # [Future] Deploys policies via Terraform (Project 7)
│   ├── 03-cost-security.yml    # [Future] Budgets + Defender
│   └── 04-provisioning.yml     # [Future] Blueprints + subscription factory
├── docs/
└── vars/
    ├── common.tfvars           # Org naming, tags, regions
    └── mg-hierarchy.tfvars     # MG tree structure definition
```

### Deployment Flow

```text
1. Pipeline deploys environments/test → mg-test.tfstate
2. Validate structure and outputs → PR approval
3. Deploy environments/nonprod → mg-nonprod.tfstate
4. Validation + approval → environments/prod → mg-prod.tfstate
5. Remote state outputs published for myorg-landing-zone / myorg-shared consumption
6. All hierarchy changes managed via PRs in myorg-azuregovernance
```

**Rationale:**  
Establishing Test, Non‑Prod, and Prod hierarchies from day one ensures safe validation and consistent governance. **Test** isolates IaC risk; **Non‑Prod** and **Prod** reinforce qualitative policy differences aligned with organisational standards.
