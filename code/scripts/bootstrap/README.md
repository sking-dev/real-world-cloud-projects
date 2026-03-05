# Bootstrap Scripts

This directory contains one‑time bootstrap scripts used to establish the foundational control‑plane prerequisites required before governance and workload infrastructure can be managed via Infrastructure‑as‑Code (IaC).

These scripts are intended to be run **once per environment**, by a platform engineer with appropriate temporary privileges. They favour explicit intent, fail‑fast behaviour, and controlled privilege escalation over generic automation.

After successful execution, all ongoing governance and platform configuration must be performed via IaC.

0. create-arm-subscriptions.sh (DEPRECATED; intentionally not implemented)
1. 01-verify-subscriptions-ready.sh
2. 02-create-remote-state-resources.sh
3. 03-create-pipeline-identity.sh
4. 04-create-pipeline-service-connection.sh
5. 05-enforce-pim-owner-access.sh

---

## Subscription Creation

Azure subscriptions must be created manually by a designated enrolment or billing account with subscription‑creation permissions.

Subscription creation is a billing‑scoped operation and must not be automated from this repository. The previously proposed `create-arm-subscriptions.sh` script is intentionally not implemented.

### Rationale

Subscription creation operates at the billing boundary and carries financial and organisational risk. Restricting this action to an explicitly authorised human identity:

- Ensures financial controls are enforced
- Reduces blast radius
- Aligns with audit and least‑privilege requirements
- Preserves clear accountability

Management group hierarchy, policy assignment, and subscription governance are applied later via IaC, once subscriptions exist in the correct tenant and billing context.

---

## Secure Manual Workflow

The approved bootstrap workflow is:

- An enrolment or billing account creates the required subscriptions in the correct tenant and offer
- The enrolment user assigns the platform engineer a **temporary static Owner** role at the subscription scope
- Using this temporary access, the platform engineer:
  - Enables and configures **Privileged Identity Management (PIM)** for the subscription(s)
- The platform engineer then:
  - Validates that PIM‑eligible Owner access works
  - Removes the temporary static Owner role assignment

This ensures that ongoing administrative access is managed exclusively through PIM rather than permanent role assignments.

Subscription creation is expected to be a rare, one‑off activity. All subsequent governance configuration is performed via IaC.

---

## Execution Flow

0. MANUAL STEP (run by enrolment / billing account)
   - Create subscriptions via Azure Portal (Cost Management + Billing → Create)
   - Assign platform engineer → Owner on each new subscription
   - Record subscription IDs

1. 01-verify-subscriptions-ready.sh (run by platform engineer)
   - Verifies Owner access to target subscriptions
   - Fails immediately if access is incomplete or incorrect

2. 02-create-remote-state-resources.sh (run by platform engineer)
   - Provisions Terraform remote state resources in the governance (`prod`) subscription
   - Storage account creation is performed via ARM/Bicep due to Azure CLI limitations during bootstrap

3. 03-create-pipeline-identity.sh (run by platform engineer)
   - Creates a pipeline service principal using Azure DevOps workload identity federation (OIDC)
   - No client secrets are created or stored
   - Federation is scoped at the Azure DevOps project level
   - RBAC is intentionally limited to Terraform state access only

4. 04-create-pipeline-service-connection.sh (run by platform engineer)
   - Creates the Azure DevOps service connection referencing the federated pipeline identity
   - Authentication is validated implicitly by the first real pipeline execution

5. 05-enforce-pim-owner-access.sh (run by platform engineer)
   - Enforces the post‑bootstrap security end state
   - Removes **static human Owner** role assignments
   - Preserves:
     - PIM‑eligible Owner access
     - Explicit break‑glass accounts
   - Assumes PIM configuration has been validated manually
   - This script seals the bootstrap phase and must be run with care

---

## Bootstrap Completion Criteria

A subscription is considered **bootstrap‑complete** when:

- No permanent human Owner role assignments remain (except break‑glass)
- Owner access is available only via PIM activation
- Terraform remote state storage is provisioned and accessible
- The pipeline identity can authenticate successfully using workload identity federation
- The pipeline identity has only the minimum RBAC required at this stage
- Subscription IDs are recorded for governance IaC input

---

## Break‑Glass Access

A small number of explicitly identified break‑glass accounts may retain permanent Owner access.

These accounts exist to guarantee recovery in exceptional circumstances and are intentionally excluded from PIM enforcement scripts.

Their presence is a conscious governance decision, not an oversight.

---

## Prerequisites

- Step 0: Enrolment or billing account with subscription‑creation permissions
- Steps 1–4: Temporary Owner role on new subscriptions
- Script 03: Temporary Entra ID application administration permissions  
  (e.g. Application Administrator, activated via PIM)
- PIM configuration requires temporary Entra ID administrative elevation  
  (e.g. Privileged Role Administrator or Global Administrator)

---

## Privilege Handoff Pattern

Billing / Enrolment Account
        |
        |  MANUAL (subscription creation)
        v
Temporary Static Owner
        |
        |  PIM configuration + validation
        v
PIM‑Only Owner --> Ongoing platform operations

---

## Appendix: PIM Configuration Checklist (Manual)

Privileged Identity Management (PIM) configuration is intentionally **not automated** as part of the bootstrap scripts.  
It is a sensitive identity‑governance operation and must be performed and validated by a platform engineer.

This appendix documents the expected manual steps.

---

### 1. Elevate Entra ID permissions

- Activate **Privileged Role Administrator** (or Global Administrator) via Entra ID PIM
- Confirm elevation is active before proceeding

---

### 2. Create domain access groups (Entra ID)

Create the following security groups for the governance domain:

- az-sub-myorg-azuregovernance-allenv-readers
- PIM_az-sub-myorg-azuregovernance-allenv-contributors
- PIM_az-sub-myorg-azuregovernance-allenv-owners

Notes:

- Group membership defines **who** can access
- Groups themselves are **not** PIM‑managed
- The `PIM_` prefix indicates intended use in PIM‑eligible role assignments

---

### 3. Assign roles at subscription scope

#### Owner (PIM‑eligible)

- Azure Portal → Privileged Identity Management → Azure resources
- Select the governance (`prod`) subscription
- Add **Eligible** role assignment:
  - Role: **Owner**
  - Member: `PIM_…-owners`
  - Activation settings: match organisational standards

#### Reader (Permanent)

- Azure Portal → Subscription → Access control (IAM)
- Add **Permanent** role assignment:
  - Role: **Reader**
  - Member: `…-readers`

Reader access is intentionally not PIM‑gated.

---

### 4. Validate PIM works

- Add a second platform engineer to the `PIM_…-owners` group
- Have that engineer activate **Owner** via PIM
- Confirm activation succeeds

This validation is required before enforcing PIM‑only access.

---

### 5. Enforce PIM‑only Owner access

Once PIM has been configured and validated:

- Run `05-enforce-pim-owner-access.sh`
- The script will:
  - Remove static human Owner assignments
  - Preserve explicit break‑glass accounts
  - Leave Owner access available only via PIM

---

### 6. De‑elevate

- Deactivate Entra ID administrative roles
- Bootstrap identity phase is complete

---
