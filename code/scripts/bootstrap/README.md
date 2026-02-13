# Bootstrap Scripts

One‑time setup (subscriptions, remote state, pipeline identity) that must exist before this project and future projects can support subsequent IaC‑controlled deployments.

```text
1. create-arm-subscriptions.sh - DEPRECATED (intentionally not implemented)
2. create-remote-state-resources.sh
3. create-pipeline-spn.sh
4. create-pipeline-service-connection.sh
5. assign-pim-roles.sh
```

## Subscription Creation

New Azure subscriptions must be created manually by a designated EA account with subscription‑creation rights. Subscription creation is a controlled billing operation and cannot be safely or appropriately automated from this repository.

The original intention to provide a `create-arm-subscriptions.sh` script has therefore been deliberately superseded.

### Why this is Manual

Subscription creation is intentionally excluded from automation because it operates at the billing boundary and carries financial risk. Restricting this step to an explicitly authorised human identity reduces blast radius and aligns with least‑privilege and audit requirements.

Management group creation and subscription placement are performed later via IaC, once these prerequisite subscriptions and identities exist.

### Secure Manual Workflow

The recommended bootstrap process is:

- A designated "SubCreate" EA enrolment account (with subscription‑creation rights) creates each required subscription in the correct tenant and offer
- The SubCreate user assigns the platform engineer a temporary static Owner role at the subscription scope
- Using this temporary ownership, the engineer:
  - Enables and configures Privileged Identity Management (PIM) for the subscription(s)
- The engineer then:
  - Uses PIM to activate eligible Owner access
  - Removes the temporary static Owner role assignment

This ensures that ongoing administrative elevation is managed exclusively through PIM, rather than through permanent role assignments.

Subscription creation is expected to be a rare, one‑off bootstrap activity. All subsequent governance configuration is performed via IaC.

## Execution Flow

```text
0. MANUAL STEP (run by enrolment account e.g. SubCreate@organisation.com)
   - Create platform subscriptions via Portal (Cost Management + Billing → Create)
   - Assign YOUR_EMAIL → Owner on each new subscription (IAM → Add → Owner)
   - Note subscription IDs

1. **verify-subscriptions-ready.sh** (run by platform engineer)
   - Confirms engineer has Owner access to target subscriptions
   - Fails fast if handoff incomplete

2. **create-remote-state-resources.sh** (run by engineer)  
3. **create-pipeline-spn.sh** (run by engineer)
4. **create-pipeline-service-connection.sh** (run by engineer)
5. **assign-pim-roles.sh** (run by engineer) → replace static Owner with PIM eligible
  - Removes all permanent Owner assignments
```

## Prerequisites

- Step 0: SubCreate account access (enrolment account with billing scope)
- Steps 1-5: Owner role on new subscriptions (granted manually in step 0)

## Handoff Pattern

```text
Billing Admin (SubCreate) ── MANUAL ──► Static Owner ──► Platform Engineer
                                             │
                                     IaC + PIM eligible Owner
```
