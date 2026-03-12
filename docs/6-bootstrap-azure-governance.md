# Project 6: Bootstrapping Azure Governance Prerequisites

⚙️ **Draft version — content under review and subject to refinement.**

## Context

Hub‑and‑spoke landing zone architectures and governance‑as‑code need **somewhere to run**: subscriptions, identities, and pipelines must exist before you can scaffold management groups and policies with IaC.

This project provisions the **foundational Azure resources** required to support the governance control plane: a small set of flat Azure subscriptions dedicated to governance tooling, shared services, identities, and CI/CD plumbing for the `myorg-azuregovernance` repository.

The output is a minimal but production‑grade **governance execution environment** that Project 7 (Scaffolding Governance in Azure) builds on, without defining the full landing zone subscription topology yet.

**Important:** This project intentionally distinguishes between subscription onboarding (a rare, high‑impact bootstrap activity) and ongoing governance enforcement. Subscription creation and initial onboarding require explicit human intent and are therefore not fully automated, while all subsequent governance controls are enforced via infrastructure‑as‑code.

## Requirements

- Create a small set of Azure subscriptions dedicated to governance tooling and IaC support using a simple flat structure at this stage.
  - Although a full set of environment‑aligned governance subscriptions is created, governance resources are initially deployed only to the production (prod) governance subscription. Additional subscriptions remain unused until a concrete governance or platform need arises.
    - `sub-myorg-azuregovernance-dev`
    - `sub-myorg-azuregovernance-uat`
    - `sub-myorg-azuregovernance-preprod`
    - `sub-myorg-azuregovernance-prod`  
- Provision **identity and access** for governance automation (service principals or managed identities) with least‑privilege at the tenant root and subscription scopes.
- Stand up a **CI/CD platform** (e.g. Azure DevOps organisation / GitHub org) and connect it to the Azure tenant.
  - Service connection creation uses Azure DevOps UI (automatic mode) to ensure atomic creation of app registration and federated credential.
  - Bootstrap script validates the service connection and configures minimal RBAC.
- Create the initial **`myorg-azuregovernance` repository** with basic structure, branching, and protection rules.
- Validate that the governance pipeline can **authenticate and perform read‑only operations** at the tenant and subscription scopes.
- Keep all configuration **scripted or IaC‑driven** (Bash, Azure CLI, Terraform) wherever Azure supports it.

## Architecture

- **Subscriptions:**
  - `sub-myorg-azuregovernance-dev` — holds non‑production governance tooling and IaC support resources.
  - `sub-myorg-azuregovernance-uat` and `sub-myorg-azuregovernance-pp` — used for higher‑confidence validation of governance tooling and IaC changes before production.
  - `sub-myorg-azuregovernance-prod` — production governance subscription hosting state, secrets, and CI/CD resources that drive live scaffolding and policy deployments.
  - **Note:** Azure governance is treated as a single control plane, not as four independent environments. Environment‑aligned governance subscriptions exist for pattern consistency and future flexibility, not because governance workloads inherently require environment separation.
- **Resource groups (in governance subscriptions):**
  - In each governance subscription, `rg-governance-core` — service principals, managed identities, Key Vault, storage for state/logs.
  - `rg-governance-ci` — agents, pipeline artefact storage, and supporting services.
- **Identities and access:**
  - **Workload identity** for governance IaC created automatically by Azure DevOps when service connection is established.
  - Initial role assignments (bootstrap phase):
    - `Storage Blob Data Contributor` on Terraform state storage account only (least privilege).
  - Additional role assignments (scaffolding phase, applied via separate scripts):
    - Tenant root / initial management group: `Owner` or `Contributor` plus `Resource Policy Contributor` (or equivalent custom roles) for the IaC identity.
    - Each `sub-myorg-azuregovernance-*` subscription for hosting governance infrastructure.
- **CI/CD integration:**
  - Azure DevOps or GitHub project connected to the Azure tenant.
  - Service connection or OIDC configuration for `myorg-azuregovernance` pipelines.
- **State and secrets:**
  - Azure Storage account for Terraform remote state (for example, `stmyorggovtfstate`) and state containers.
  - Azure Key Vault for storing SPN secrets or federated credentials configuration, if applicable.
  - Governance infrastructure uses a **single Terraform remote state** stored in the production governance subscription. State is not split by environment, as management groups and policies are tenant‑scoped concerns.

## Key Decisions

- **Subscription layout for governance:**
  - Use a simple, environment‑aligned set of governance subscriptions (`dev`, `uat`, `pp`, `prod`) to host IaC state, secrets, and CI/CD resources, deferring landing zone subscription design to later projects.  Governance subscriptions are created as a flat, environment‑aligned set; however, **only the production subscription is expected to host active governance resources initially**.
- **Identity pattern:**
  - Use **workload identity federation (OIDC)** for CI/CD pipelines.
  - App registration and federated credential are created automatically by Azure DevOps (automatic mode).
  - No client secrets or certificates are created or stored.
  - This approach prevents configuration mismatches between Entra ID and Azure DevOps.
- **State location:**
  - Decide where **Terraform state** and pipeline artefacts will live (storage account, naming, redundancy, region).
- **CI/CD platform:**
  - Pick and configure the primary CI/CD platform (Azure DevOps vs GitHub), including how it connects to Azure and how approvals will work.
- **Access boundaries:**
  - Decide the **minimum scopes** where governance IaC needs permissions (tenant root vs first‑level management group vs specific subscriptions).
- **Bootstrap execution model:**
  - Bootstrap activities combine **manual steps** (subscription creation, service connection creation) with **validation scripts** (access verification, RBAC configuration).
  - Service connection creation is performed manually via Azure DevOps UI to leverage automatic mode (atomic app registration + federated credential creation).
  - Scripts validate configuration and assign minimal RBAC, ensuring explicit intent at high‑privilege and billing boundaries.
  - This hybrid approach is intentional: Microsoft explicitly states automatic mode is not supported for non-user principals in automation.
- **Bootstrap completion criteria:**
  - A subscription is considered bootstrap‑complete when ownership is normalised via PIM, remote state and secrets are provisioned, and the governance pipeline can authenticate and perform non‑destructive operations.

## Bootstrap Approach: Manual + Scripted

The bootstrap process intentionally combines manual steps with validation scripts:

### Manual Steps (Azure DevOps UI)

- **Service connection creation** using workload identity federation (automatic mode)
  - Azure DevOps creates app registration and federated credential atomically
  - Prevents configuration mismatches between Entra ID and Azure DevOps
  - Microsoft's officially supported approach for this workflow

### Scripted Steps (Bash + Azure CLI)

- **Subscription verification** — confirms access and correct hand-off
- **Remote state provisioning** — creates storage account and containers
- **Service connection validation** — verifies OIDC configuration
- **RBAC assignment** — grants minimal permissions (state storage only initially)

### Rationale

- **Atomic operations:** Automatic mode ensures app registration and federated credential are created together, eliminating race conditions and mismatches
- **Microsoft guidance:** Automatic mode is not supported for non-user principals in automation scenarios
- **Fail-fast validation:** Scripts verify configuration immediately after manual steps
- **Least privilege:** Initial RBAC is intentionally minimal; additional permissions are granted later via scaffolding scripts

## Operations

The following steps describe the intended execution flow, combining required manual actions at the billing and tenant‑privilege boundary with scripted automation for repeatable setup tasks.

- Created `sub-myorg-azuregovernance-dev`, `sub-myorg-azuregovernance-uat`, `sub-myorg-azuregovernance-pp`, and `sub-myorg-azuregovernance-prod` as a flat set of governance subscriptions under the tenant root to host IaC support and governance tooling.
- Provisioned a `rg-governance-core` resource group in the dev and prod governance subscriptions and deployed:
  - Terraform state storage account and containers.
  - Key Vault for governance secrets.
- Created **service connection** in Azure DevOps UI using workload identity federation (automatic mode):
  - Azure DevOps automatically created app registration and federated credential.
  - Bootstrap script validated configuration and assigned initial RBAC:
    - `Storage Blob Data Contributor` on Terraform state storage account only.
  - Additional RBAC assignments (tenant root, governance subscriptions) are deferred to scaffolding phase and applied via separate scripts.
- Set up an Azure DevOps organisation and:
  - Created the `myorg-azuregovernance` project and repository.
  - Manually created service connection via UI (Project settings > Pipelines > Service connections):
    - Type: Azure Resource Manager
    - Authentication: Workload Identity federation (automatic)
    - This creates app registration and federated credential atomically.
  - Ran bootstrap script to validate service connection and configure RBAC.
  - Enabled branch protections and PR validation policies on `main`.
- Committed initial repo scaffolding:
  - `/docs/` with high‑level governance notes.
  - `/scripts/bootstrap/` for Bash bootstrap scripts (subscription creation, SPN creation, role assignment).
  - `/infra/bootstrap/` for Terraform or CLI definitions for state storage, Key Vault, and base role assignments.
- Ran a **smoke test pipeline** that:
  - Authenticates via the governance identity.
  - Reads tenant root and subscription details.
  - Confirms it can manage state storage and Key Vault in the governance subscriptions.

## Future Enhancements

- Explore a controlled **subscription request and onboarding workflow** (e.g. approval‑gated automation) rather than fully manual creation, while retaining explicit human authorisation at the billing boundary.
- Extend bootstrap IaC to create the **initial management groups**, paving the way for Project 6 to take full ownership.
- Add monitoring and alerting for governance pipelines and state storage, including access anomalies and deployment failures.

## Code References

*Paths to be finalised once repository structure is stabilised.*

- `/code/myorg-azuregovernance/scripts/bootstrap/` — **Bash scripts** for one‑time setup tasks (subscription creation, SPN creation, role assignment) with **README.md** documenting script sequence and prerequisites.
- `/code/myorg-azuregovernance/scripts/bootstrap/README.md` — **Detailed sequencing instructions** for running bootstrap scripts manually or via initial CI/CD.
- `/code/myorg-azuregovernance/infra/bootstrap/` — Terraform or CLI definitions for state storage, Key Vault, and base role assignments.
- `/code/myorg-azuregovernance/pipelines/00-bootstrap.yml` — Bootstrap pipeline to validate access and deploy foundational resources.

## Appendix: Example Bootstrap Script Flow

```text
1. Authenticate interactively as a PIM‑eligible platform engineer, elevating only for the duration of the bootstrap process.
2. Create governance subscriptions:
   - sub-myorg-azuregovernance-dev
   - sub-myorg-azuregovernance-uat
   - sub-myorg-azuregovernance-pp
   - sub-myorg-azuregovernance-prod
3. Create rg-governance-core in the relevant governance subscriptions.
4. Deploy storage account + containers for Terraform state.
5. Deploy Key Vault and configure access policies.
6. Manually create service connection in Azure DevOps UI (workload identity federation, automatic mode).
7. Run bootstrap script to validate service connection and assign minimal RBAC (state storage access only).
8. Record application ID and service principal ID for reference (no secrets to store).
