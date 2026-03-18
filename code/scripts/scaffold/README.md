# Scaffold Scripts

This directory contains **one-time scaffold scripts** used to configure elevated permissions required for Azure governance Infrastructure-as-Code (IaC) deployment.

These scripts are run **after bootstrap is complete** and **before Terraform deployments begin**. They extend the pipeline service principal's permissions to enable management group creation, policy assignment, and governance at scale.

The scaffold phase builds on the minimal permissions established during bootstrap, granting only the additional RBAC required for governance operations.

After scaffold is complete, **all ongoing governance configuration must be performed via IaC**.

## Script Inventory

1. 01-extend-pipeline-permissions.sh  
   Extends pipeline service principal RBAC to enable management group and policy scaffolding

---

## Scaffold Workflow

### Prerequisites

Before running scaffold scripts, ensure:

- ✅ Bootstrap phase is complete (`scripts/bootstrap/`)
- ✅ Service connection exists and uses workload identity federation (OIDC)
- ✅ Terraform remote state storage is provisioned and accessible
- ✅ Pipeline service principal has Storage Blob Data Contributor on state storage

---

### Step 1 — Extend Pipeline Permissions

**Script:** `01-extend-pipeline-permissions.sh`

**Prerequisites:**

- User Access Administrator at Tenant Root Group (via PIM)
- Owner on subscription `sub-myorg-azuregovernance-prod` (via PIM)

**What the script does:**

- Validates the service connection exists and retrieves service principal details
- Verifies bootstrap RBAC (Terraform state access) is still present
- Assigns the following roles at Tenant Root Group scope:
  - **Management Group Contributor** — Create and manage management groups
  - **Resource Policy Contributor** — Assign policies and initiatives
- Idempotent — safe to run multiple times (only adds missing roles)
- Additive only — never removes existing role assignments

**PIM Configuration (one-time):**

This script requires PIM to be configured for the Tenant Root Group. If not already configured:

1. **Activate Global Administrator** (via PIM in Entra ID)
2. **Navigate to PIM** → Azure resources
3. **Discover and onboard** Tenant Root Group to PIM
4. **Create security group:** `PIM_az-mg-tenantroot-useraccessadmin`
   - Description: "PIM-eligible for User Access Administrator at Tenant Root Group scope. Enables platform engineers to assign Azure RBAC at tenant level."
   - Members: Platform engineering team
5. **Configure role settings** for User Access Administrator:
   - Activation maximum duration: 1 hour
   - Require justification: Yes
   - Require approval: Yes (recommended)
   - Approvers: Senior platform engineers / security team
6. **Add eligible assignment:**
   - Role: User Access Administrator
   - Scope: Tenant Root Group
   - Members: `PIM_az-mg-tenantroot-useraccessadmin` group
   - Duration: 1 year (renewable)

**Usage:**

```bash
# 1. Activate required PIM roles
#    - User Access Administrator at Tenant Root Group (1 hour)
#    - Owner on sub-myorg-azuregovernance-prod (1 hour)

# 2. Refresh Azure CLI credentials
az logout
az login

# 3. Run the script
cd scripts/scaffold./01-extend-pipeline-permissions.sh
```

**Rationale for manual PIM configuration:**

- PIM configuration is a sensitive identity-governance operation
- Requires explicit human intent and approval
- Establishes time-bound, auditable access to tenant-level permissions
- Aligns with zero standing privilege principle

---

## Scaffold Completion Criteria

Scaffold is complete when **all** of the following are true:

- Pipeline service principal has Management Group Contributor at Tenant Root Group
- Pipeline service principal has Resource Policy Contributor at Tenant Root Group
- Bootstrap RBAC (Terraform state access) is preserved
- All role assignments are verified and documented
- PIM configuration for Tenant Root Group is validated

---

## Privilege Escalation Pattern

```text
Bootstrap (Minimal Permissions)
        |
        |  Storage Blob Data Contributor (state access only)
        v
Scaffold (Governance Permissions)
        |
        |  Management Group Contributor + Resource Policy Contributor
        v
IaC Deployment --> Ongoing governance operations
```

This model ensures:

- Permissions are granted incrementally with explicit intent
- Each phase has only the minimum RBAC required
- High-privilege operations require PIM activation
- All changes are auditable and time-bound

---

## Troubleshooting

### Issue: `AuthorizationFailed` when assigning roles at tenant root

**Cause:** User Access Administrator role not active or not propagated

**Solution:**

1. Verify PIM activation is approved and active (Portal → PIM → My roles → Azure resources)
2. Wait 5-10 minutes for propagation
3. Run `az logout && az login` to refresh token
4. Verify role is visible:

   ```bash
   az role assignment list --all --assignee <your-email> \
     --query "[?roleDefinitionName=='User Access Administrator']"
   ```

### Issue: Script cannot find service connection

**Cause:** Bootstrap script `03-create-pipeline-service-connection.sh` not run

**Solution:** Complete bootstrap phase before running scaffold scripts

### Issue: Bootstrap RBAC verification fails

**Cause:** Pipeline service principal no longer has access to Terraform state storage

**Solution:** Re-run bootstrap script `03-create-pipeline-service-connection.sh`

---

## Important Notes

- **High-privilege operation:** This grants tenant-level permissions to the pipeline identity
- **Time-bound access:** PIM roles expire after activation period (1 hour for User Access Administrator)
- **Audit trail:** All activations and role assignments are logged in Azure Activity Log
- **Principle of least privilege:** Only grants permissions required for governance scaffolding
- **No secrets:** Uses workload identity federation (OIDC) — no client secrets involved
- **Separation of concerns:** Terraform uses these permissions but does not manage them (avoids chicken-and-egg problems)

---

## After Scaffold

The pipeline service principal has the permissions required to deploy:

- Management group hierarchies (via Terraform)
- Azure Policy definitions and assignments
- RBAC at management group scopes

Proceed to deploy governance infrastructure via the `myorg-azuregovernance` repository pipelines.

---

## Notes

- Scaffold scripts are **not** part of steady-state automation
- Re-running scripts after initial scaffold should be done only with full understanding of impact
- All ongoing governance changes should be made via IaC, not by re-running scaffold scripts
- Manual changes to management groups or policies should be avoided
