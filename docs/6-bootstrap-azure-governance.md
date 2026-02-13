# Project 6: Bootstrapping Azure Governance Prerequisites

⚙️ **Draft version — content under review and subject to refinement.**

## Context

Hub‑and‑spoke landing zone architectures and governance‑as‑code need **somewhere to run**: subscriptions, identities, and pipelines must exist before you can scaffold management groups and policies with IaC.

This project provisions the **foundational Azure resources** required to support the governance control plane: a small set of flat Azure subscriptions dedicated to governance tooling, shared services, identities, and CI/CD plumbing for the `myorg-azuregovernance` repository.

The output is a minimal but production‑grade **governance execution environment** that Project 7 (Scaffolding Governance in Azure) builds on, without defining the full landing zone subscription topology yet.

## Requirements

- Create a small set of Azure subscriptions dedicated to governance tooling and IaC support using a simple flat structure at this stage.
  - `sub-myorg-azuregovernance-dev`
  - `sub-myorg-azuregovernance-uat`
  - `sub-myorg-azuregovernance-preprod`
  - `sub-myorg-azuregovernance-prod`
- Provision **identity and access** for governance automation (service principals or managed identities) with least‑privilege at the tenant root and subscription scopes.
- Stand up a **CI/CD platform** (e.g. Azure DevOps organisation / GitHub org) and connect it to the Azure tenant.
- Create the initial **`myorg-azuregovernance` repository** with basic structure, branching, and protection rules.
- Validate that the governance pipeline can **authenticate and perform read‑only operations** at the tenant and subscription scopes.
- Keep all configuration **scripted or IaC‑driven** (Bash, Azure CLI, Terraform) wherever Azure supports it.

## Architecture

- **Subscriptions:**
  - `sub-myorg-azuregovernance-dev` — holds non‑production governance tooling and IaC support resources.
  - `sub-myorg-azuregovernance-uat` and `sub-myorg-azuregovernance-pp` — used for higher‑confidence validation of governance tooling and IaC changes before production.
  - `sub-myorg-azuregovernance-prod` — production governance subscription hosting state, secrets, and CI/CD resources that drive live scaffolding and policy deployments.
- **Resource groups (in governance subscriptions):**
  - In each governance subscription, `rg-governance-core` — service principals, managed identities, Key Vault, storage for state/logs.
  - `rg-governance-ci` — agents, pipeline artefact storage, and supporting services.
- **Identities and access:**
  - One or more **service principals / workload identities** for governance IaC (e.g. `spn-myorg-azuregovernance`).
  - Role assignments at:
    - Tenant root / initial management group: `Owner` or `Contributor` plus `Resource Policy Contributor` (or equivalent custom roles) for the IaC identity.
    - Each `sub-myorg-azuregovernance-*` subscription for hosting governance infrastructure.
- **CI/CD integration:**
  - Azure DevOps or GitHub project connected to the Azure tenant.
  - Service connection or OIDC configuration for `myorg-azuregovernance` pipelines.
- **State and secrets:**
  - Azure Storage account for Terraform remote state (for example, `stmyorggovtfstate`) and state containers.
  - Azure Key Vault for storing SPN secrets or federated credentials configuration, if applicable.

## Key Decisions

- **Subscription layout for governance:**
  - Use a simple, environment‑aligned set of governance subscriptions (`dev`, `uat`, `pp`, `prod`) to host IaC state, secrets, and CI/CD resources, deferring landing zone subscription design to later projects.
- **Identity pattern:**
  - Choose between **service principal + secret**, **service principal + certificate**, or **federated/OIDC identities** for CI/CD pipelines.
- **State location:**
  - Decide where **Terraform state** and pipeline artefacts will live (storage account, naming, redundancy, region).
- **CI/CD platform:**
  - Pick and configure the primary CI/CD platform (Azure DevOps vs GitHub), including how it connects to Azure and how approvals will work.
- **Access boundaries:**
  - Decide the **minimum scopes** where governance IaC needs permissions (tenant root vs first‑level management group vs specific subscriptions).

## Operations

- Created `sub-myorg-azuregovernance-dev`, `sub-myorg-azuregovernance-uat`, `sub-myorg-azuregovernance-pp`, and `sub-myorg-azuregovernance-prod` as a flat set of governance subscriptions under the tenant root to host IaC support and governance tooling.
- Provisioned a `rg-governance-core` resource group in the dev and prod governance subscriptions and deployed:
  - Terraform state storage account and containers.
  - Key Vault for governance secrets.
- Registered a **service principal** for governance IaC (`spn-myorg-azuregovernance`) and granted:
  - `Owner` and policy‑related roles at tenant root (or a bootstrap management group) to allow management group creation and policy assignment later.
  - `Contributor` on the `sub-myorg-azuregovernance-*` governance subscriptions.
- Set up an Azure DevOps organisation (or GitHub org) and:
  - Created the `myorg-azuregovernance` project and repository.
  - Configured a service connection or OIDC trust to the governance SPN or workload identity.
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

- Automate subscription creation via a **subscription factory** pipeline rather than manual creation.
- Extend bootstrap IaC to create the **initial management groups**, paving the way for Project 6 to take full ownership.
- Harden security by migrating from SPN secrets to **federated credentials / managed identities** where supported.
- Add monitoring and alerting for governance pipelines and state storage, including access anomalies and deployment failures.

## Code References

*Paths to be finalised once repository structure is stabilised.*

- `/code/myorg-azuregovernance/scripts/bootstrap/` — **Bash scripts** for one‑time setup tasks (subscription creation, SPN creation, role assignment) with **README.md** documenting script sequence and prerequisites.
- `/code/myorg-azuregovernance/scripts/bootstrap/README.md` — **Detailed sequencing instructions** for running bootstrap scripts manually or via initial CI/CD.
- `/code/myorg-azuregovernance/infra/bootstrap/` — Terraform or CLI definitions for state storage, Key Vault, and base role assignments.
- `/code/myorg-azuregovernance/pipelines/00-bootstrap.yml` — Bootstrap pipeline to validate access and deploy foundational resources.

## Appendix: Example Bootstrap Script Flow

```text
1. Authenticate as a tenant admin (interactive).
2. Create governance subscriptions:
   - sub-myorg-azuregovernance-dev
   - sub-myorg-azuregovernance-uat
   - sub-myorg-azuregovernance-pp
   - sub-myorg-azuregovernance-prod
3. Create rg-governance-core in the relevant governance subscriptions.
4. Deploy storage account + containers for Terraform state.
5. Deploy Key Vault and configure access policies.
6. Create governance service principal / federated identity.
7. Assign roles at tenant root and governance subscriptions.
8. Output IDs and secrets into Key Vault and a local config file.
```
