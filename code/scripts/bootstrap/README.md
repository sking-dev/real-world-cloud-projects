# Bootstrap Scripts

This directory contains one-time bootstrap scripts that establish the foundational control-plane prerequisites required before governance and workload infrastructure can be managed safely via Infrastructure-as-Code (IaC).

These scripts intentionally favour explicit intent, fail-fast behaviour, and human-controlled privilege escalation over generic automation. They are designed to be run rarely, deliberately, and by a platform engineer with appropriate temporary privileges.

Once these steps are complete, all subsequent governance and platform configuration is expected to be performed via IaC.

0. create-arm-subscriptions.sh (DEPRECATED; intentionally not implemented)
1. 01-verify-subscriptions-ready.sh
2. 02-create-remote-state-resources.sh
3. 03-create-pipeline-identity.sh
4. 04-create-pipeline-service-connection.sh
5. 05-assign-pim-roles.sh

---

## Subscription Creation

New Azure subscriptions must be created manually by a designated enrolment / billing account with subscription-creation rights.

Subscription creation is a controlled billing operation and cannot be safely or appropriately automated from this repository. The original intention to provide a create-arm-subscriptions.sh script has therefore been deliberately superseded.

### Why This Is Manual

Subscription creation operates at the billing boundary and carries financial, contractual, and organisational risk.

Restricting this step to an explicitly authorised human identity:

- Reduces blast radius
- Aligns with least-privilege and audit expectations
- Avoids accidental or uncontrolled spend
- Ensures clear accountability

Management group creation, policy assignment, and subscription placement are performed later via IaC, once these prerequisite subscriptions and identities exist.

This manual boundary also ensures that subsequent identity and governance bootstrapping occurs only after subscriptions exist within a known tenant and billing context.

---

## Secure Manual Workflow

The recommended bootstrap workflow is:

- A designated enrolment account (e.g. `SubCreate@organisation.com`) creates each required subscription in the correct tenant and billing offer
- The enrolment user assigns the platform engineer a temporary static Owner role at the subscription scope
- Using this temporary ownership, the platform engineer:
  - Enables and configures Privileged Identity Management (PIM) for the subscription(s)
- The engineer then:
  - Activates eligible Owner access via PIM
  - Removes the temporary static Owner role assignment

This ensures that ongoing administrative elevation is managed exclusively through PIM rather than permanent role assignments.

Subscription creation is expected to be a rare, one-off bootstrap activity. All subsequent governance configuration is performed via IaC.

---

## Execution Flow

0. MANUAL STEP (run by enrolment / billing account)
   - Create platform subscriptions via Portal (Cost Management + Billing → Create)
   - Assign YOUR_EMAIL → Owner on each new subscription (IAM → Add → Owner)
   - Record subscription IDs

1. 01-verify-subscriptions-ready.sh (run by platform engineer)
   - Confirms the engineer has Owner access to target subscriptions
   - Fails fast if handoff is incomplete or ambiguous

2. 02-create-remote-state-resources.sh (run by platform engineer)
   - Provisions Terraform remote state resources in the governance (prod) subscription
   - Storage account creation is performed via ARM/Bicep due to known Azure CLI limitations in bootstrap contexts

3. 03-create-pipeline-identity.sh (run by platform engineer)
   - Creates a pipeline service principal using Azure DevOps workload identity federation (OIDC)
   - No client secrets are created or stored
   - Federation is scoped at the Azure DevOps project level
   - RBAC is intentionally limited to Terraform state access only

4. 04-create-pipeline-service-connection.sh (run by platform engineer)
   - Creates the Azure DevOps service connection referencing the federated pipeline identity

5. 05-assign-pim-roles.sh (run by platform engineer)
   - Removes all permanent Owner role assignments
   - Ensures all ongoing administrative access is PIM-controlled
   - This is the final bootstrap step and should be run only after all other scripts succeed

---

## Bootstrap Completion Criteria

A subscription is considered bootstrap-complete when:

- No permanent human Owner role assignments remain
- PIM eligible Owner access is configured for platform engineers
- Terraform remote state storage is provisioned and accessible
- The pipeline identity can authenticate successfully using workload identity federation
- The pipeline identity has only the minimum RBAC required at this stage
- Subscription IDs are recorded as inputs for governance IaC

---

## Prerequisites

- Step 0: Enrolment / billing account access with subscription-creation rights
- Steps 1–5: Temporary Owner role on new subscriptions (granted manually in Step 0)
- Script 03: Temporary Entra ID application administration permissions (e.g. Application Administrator, typically activated via PIM)

---

## Handoff Pattern

Billing Admin (enrolment account)
        |
        |  MANUAL (subscription creation)
        v
Temporary Static Owner
        |
        |  IaC + PIM enablement
        v
PIM Eligible Owner --> Ongoing platform operations

This handoff pattern ensures that:

- High-risk actions are human-controlled
- Privilege escalation is time-bound and auditable
- Long-lived standing access is avoided
