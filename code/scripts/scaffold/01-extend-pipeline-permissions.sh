#!/usr/bin/env bash

set -euo pipefail

echo "[INFO] Granting pipeline permissions for Azure governance scaffolding"
echo "[INFO] Script: scripts/scaffold/01-extend-pipeline-permissions.sh"
echo "[INFO] This script assigns RBAC required for management group and policy scaffolding"
echo

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# Azure / Entra ID
EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
EXPECTED_SUBSCRIPTION_NAME="sub-myorg-azuregovernance-prod"
SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Azure DevOps
AZDO_ORG_NAME="myazdoorg"
AZDO_PROJECT_NAME="myorg-azuregovernance"
AZDO_ORG_URL="https://dev.azure.com/${AZDO_ORG_NAME}"

# Service connection (from bootstrap)
SERVICE_CONNECTION_NAME="az-sub-myorg-azuregovernance-spn-prod"

# Terraform state (from bootstrap)
STATE_RESOURCE_GROUP_NAME="rg-uks-azuregovernance-tfstate-prod"
STATE_STORAGE_ACCOUNT_NAME="stmyorgtfstatexxxxxx"

# RBAC configuration
ASSIGNMENT_SCOPE="/providers/Microsoft.Management/managementGroups/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Tenant Root Group
REQUIRED_ROLES=(
  "Management Group Contributor"
  "Resource Policy Contributor"
)

# -------------------------------------------------------------------
# PRE-FLIGHT: AZURE CLI
# -------------------------------------------------------------------

echo "[INFO] Verifying Azure CLI authentication"
az account show >/dev/null

CURRENT_TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ "$CURRENT_TENANT_ID" != "$EXPECTED_TENANT_ID" ]]; then
  echo "[ERROR] Logged into wrong tenant"
  echo "        Expected: $EXPECTED_TENANT_ID"
  echo "        Actual:   $CURRENT_TENANT_ID"
  exit 1
fi

ACTUAL_SUBSCRIPTION_NAME=$(az account show \
  --subscription "$SUBSCRIPTION_ID" \
  --query name \
  -o tsv)

if [[ "$ACTUAL_SUBSCRIPTION_NAME" != "$EXPECTED_SUBSCRIPTION_NAME" ]]; then
  echo "[ERROR] Subscription ID does not match expected subscription"
  echo "        Expected name: $EXPECTED_SUBSCRIPTION_NAME"
  echo "        Actual name:   $ACTUAL_SUBSCRIPTION_NAME"
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"

echo "[OK] Azure context verified"
echo

# -------------------------------------------------------------------
# PRE-FLIGHT: AZURE DEVOPS CLI
# -------------------------------------------------------------------

echo "[INFO] Verifying Azure DevOps CLI extension"

if ! az extension show --name azure-devops >/dev/null 2>&1; then
  echo "[ERROR] Azure DevOps CLI extension is not installed"
  echo "        Run: az extension add --name azure-devops"
  exit 1
fi

echo "[OK] Azure DevOps CLI extension present"
echo

echo "[INFO] Verifying Azure DevOps CLI context"

az devops configure \
  --defaults organization="${AZDO_ORG_URL}" project="${AZDO_PROJECT_NAME}"

# Verify authentication and project access
az devops project show \
  --project "${AZDO_PROJECT_NAME}" \
  --organization "${AZDO_ORG_URL}" \
  >/dev/null

echo "[OK] Azure DevOps context verified"
echo

# -------------------------------------------------------------------
# RETRIEVE SERVICE PRINCIPAL DETAILS
# -------------------------------------------------------------------

echo "[INFO] Retrieving service principal details from service connection"

SERVICE_ENDPOINT_ID=$(az devops service-endpoint list \
  --organization "${AZDO_ORG_URL}" \
  --project "${AZDO_PROJECT_NAME}" \
  --query "[?name=='${SERVICE_CONNECTION_NAME}'].id | [0]" \
  -o tsv)

if [[ -z "$SERVICE_ENDPOINT_ID" ]]; then
  echo "[ERROR] Service connection not found: ${SERVICE_CONNECTION_NAME}"
  echo "        Run bootstrap script scripts/bootstrap/03-create-pipeline-service-connection.sh first"
  exit 1
fi

echo "[OK] Service connection found: ${SERVICE_ENDPOINT_ID}"

SC_DETAILS=$(az devops service-endpoint show \
  --id "${SERVICE_ENDPOINT_ID}" \
  --organization "${AZDO_ORG_URL}" \
  --project "${AZDO_PROJECT_NAME}")

APP_ID=$(echo "${SC_DETAILS}" | tr -d '\n\r\t ' | grep -o '"serviceprincipalid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
  echo "[ERROR] Unable to retrieve application ID from service connection"
  exit 1
fi

echo "[OK] Application ID: ${APP_ID}"

SP_OBJECT_ID=$(az ad sp show --id "${APP_ID}" --query id -o tsv)

if [[ -z "$SP_OBJECT_ID" ]]; then
  echo "[ERROR] Unable to retrieve service principal object ID"
  exit 1
fi

echo "[OK] Service principal object ID: ${SP_OBJECT_ID}"
echo

# -------------------------------------------------------------------
# VERIFY BOOTSTRAP RBAC
# -------------------------------------------------------------------

echo "[INFO] Verifying bootstrap RBAC is still present"

STORAGE_ACCOUNT_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT_NAME}"

BOOTSTRAP_RBAC=$(az role assignment list \
  --assignee "${SP_OBJECT_ID}" \
  --role "Storage Blob Data Contributor" \
  --scope "${STORAGE_ACCOUNT_SCOPE}" \
  --query "[0].id" \
  -o tsv 2>/dev/null || echo "")

if [[ -z "$BOOTSTRAP_RBAC" ]]; then
  echo "[ERROR] Bootstrap RBAC not found"
  echo "        Expected: Storage Blob Data Contributor"
  echo "        Scope:    ${STORAGE_ACCOUNT_SCOPE}"
  echo
  echo "        This indicates the bootstrap script may need to be re-run:"
  echo "        scripts/bootstrap/03-create-pipeline-service-connection.sh"
  echo
  echo "        Without this RBAC, the pipeline cannot access Terraform state."
  exit 1
fi

echo "[OK] Bootstrap RBAC verified: Storage Blob Data Contributor"
echo "       Scope: ${STATE_STORAGE_ACCOUNT_NAME}"
echo

# -------------------------------------------------------------------
# PRE-FLIGHT: PERMISSIONS CHECK
# -------------------------------------------------------------------

echo "[INFO] Verifying required permissions for RBAC assignment"
echo "[WARN] This script requires:"
echo "       - Azure: User Access Administrator at Tenant Root Group (via PIM)"
echo "       - Azure: Owner on subscription ${EXPECTED_SUBSCRIPTION_NAME} (via PIM)"
echo "       - Scope: ${ASSIGNMENT_SCOPE}"
echo "       - This is a high-privilege operation"
echo
echo "[INFO] Assignment scope: ${ASSIGNMENT_SCOPE} (tenant root)"
echo "[INFO] Roles to be assigned:"
for role in "${REQUIRED_ROLES[@]}"; do
  echo "       - ${role}"
done
echo
read -p "Do you have the required permissions and wish to proceed? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "[ERROR] Operation cancelled by user"
  exit 1
fi

echo "[OK] Proceeding with RBAC assignment"
echo

# -------------------------------------------------------------------
# CHECK EXISTING ROLE ASSIGNMENTS
# -------------------------------------------------------------------

echo "[INFO] Checking existing role assignments at tenant root scope"

# Get all current role assignments for this service principal at tenant root
EXISTING_ASSIGNMENTS=$(az role assignment list \
  --assignee "${SP_OBJECT_ID}" \
  --scope "${ASSIGNMENT_SCOPE}" \
  --query "[].roleDefinitionName" \
  -o tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_ASSIGNMENTS" ]]; then
  echo "[OK] Existing role assignments found:"
  while IFS= read -r role; do
    echo "       - ${role}"
  done <<< "$EXISTING_ASSIGNMENTS"
else
  echo "[OK] No existing role assignments at tenant root scope"
fi

echo

# -------------------------------------------------------------------
# ASSIGN REQUIRED ROLES
# -------------------------------------------------------------------

# echo "[DEBUG] Number of roles to process: ${#REQUIRED_ROLES[@]}"
# echo "[DEBUG] Roles array contents:"
# for i in "${!REQUIRED_ROLES[@]}"; do
#   echo "       [$i] = '${REQUIRED_ROLES[$i]}'"
# done
# echo

echo "[INFO] Assigning required roles (additive only - existing roles preserved)"

ROLES_ADDED=0
ROLES_SKIPPED=0

for role in "${REQUIRED_ROLES[@]}"; do
  echo "[INFO] Processing role: ${role}"
  # echo "[DEBUG] About to check if role exists in: $EXISTING_ASSIGNMENTS"
  
  # Check if role is already assigned
  if echo "$EXISTING_ASSIGNMENTS" | grep -q "^${role}$"; then
    echo "       [SKIP] Role already assigned"
    ROLES_SKIPPED=$((ROLES_SKIPPED + 1))
    # echo "[DEBUG] ROLES_SKIPPED is now: $ROLES_SKIPPED"
  else
    echo "       [ADD] Assigning role..."
    
    az role assignment create \
      --assignee-object-id "${SP_OBJECT_ID}" \
      --assignee-principal-type ServicePrincipal \
      --role "${role}" \
      --scope "${ASSIGNMENT_SCOPE}" \
      >/dev/null
    
    echo "       [OK] Role assigned successfully"
    ROLES_ADDED=$((ROLES_ADDED + 1))
    # echo "[DEBUG] ROLES_ADDED is now: $ROLES_ADDED"
  fi
  
  # echo "[DEBUG] Finished processing ${role}, moving to next..."
  echo
done

# echo "[DEBUG] Loop completed!"

# -------------------------------------------------------------------
# VERIFY ASSIGNMENTS
# -------------------------------------------------------------------

echo "[INFO] Verifying final role assignments"

FINAL_ASSIGNMENTS=$(az role assignment list \
  --assignee "${SP_OBJECT_ID}" \
  --scope "${ASSIGNMENT_SCOPE}" \
  --query "[].roleDefinitionName" \
  -o tsv)

echo "[OK] Current role assignments at tenant root:"
while IFS= read -r role; do
  echo "       - ${role}"
done <<< "$FINAL_ASSIGNMENTS"

echo

# Verify all required roles are present
ALL_PRESENT=true
for role in "${REQUIRED_ROLES[@]}"; do
  if ! echo "$FINAL_ASSIGNMENTS" | grep -q "^${role}$"; then
    echo "[ERROR] Required role not found: ${role}"
    ALL_PRESENT=false
  fi
done

if [[ "$ALL_PRESENT" != "true" ]]; then
  echo "[ERROR] Not all required roles were assigned successfully"
  exit 1
fi

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo "[OK] Pipeline permissions configuration complete"
echo
echo "Service principal:        ${SP_OBJECT_ID}"
echo "Application ID:           ${APP_ID}"
echo
echo "RBAC Summary:"
echo "  Bootstrap (preserved):"
echo "    - Storage Blob Data Contributor (Terraform state storage)"
echo
echo "  Scaffolding (tenant root):"
echo "    - Roles added:           ${ROLES_ADDED}"
echo "    - Roles already present: ${ROLES_SKIPPED}"
echo "    - Total roles assigned:  $((ROLES_ADDED + ROLES_SKIPPED))"
echo
echo "The pipeline service principal can now:"
echo "  - Access Terraform remote state (bootstrap RBAC)"
echo "  - Create and manage management groups at all levels"
echo "  - Assign Azure Policy definitions and initiatives"
echo "  - Configure RBAC at management group scopes"
echo
echo "IMPORTANT: These are high-privilege permissions."
echo "           All changes should be made via IaC in the myorg-azuregovernanc repository."
echo "           Manual changes to management groups or policies should be avoided."
echo
