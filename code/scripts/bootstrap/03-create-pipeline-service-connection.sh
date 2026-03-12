#!/usr/bin/env bash

set -euo pipefail

echo "[INFO] Configuring Azure DevOps service connection with workload identity federation"
echo "[INFO] This script validates an existing service connection and configures RBAC"
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

# Service connection naming (aligned to org-wide convention)
SERVICE_CONNECTION_NAME="az-sub-myorg-azuregovernance-spn-prod"

# Terraform state (from Script 02)
STATE_RESOURCE_GROUP_NAME="rg-uks-azuregovernance-tfstate-prod"
STATE_STORAGE_ACCOUNT_NAME="stmyorgtfstatexxxxxx"

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
# PRE-FLIGHT: SERVICE CONNECTION EXISTS
# -------------------------------------------------------------------

echo "[INFO] Checking for service connection: ${SERVICE_CONNECTION_NAME}"

SERVICE_ENDPOINT_ID=$(az devops service-endpoint list \
  --organization "${AZDO_ORG_URL}" \
  --project "${AZDO_PROJECT_NAME}" \
  --query "[?name=='${SERVICE_CONNECTION_NAME}'].id | [0]" \
  -o tsv)

if [[ -z "$SERVICE_ENDPOINT_ID" ]]; then
  echo "[ERROR] Service connection not found: ${SERVICE_CONNECTION_NAME}"
  echo
  echo "MANUAL STEP REQUIRED:"
  echo "====================="
  echo
  echo "Prerequisites:"
  echo "  - Azure DevOps: 'Project Administrator' role"
  echo "  - Azure: Contributor or Owner on subscription"
  echo "  - Entra ID: Application Administrator or Global Administrator"
  echo "    (Required for automatic app registration creation)"
  echo
  echo "Steps to create the service connection:"
  echo "  1. Navigate to: ${AZDO_ORG_URL}/${AZDO_PROJECT_NAME}/_settings/adminservices"
  echo "     (Or: Project settings > Pipelines > Service connections)"
  echo "  2. Click 'New service connection' (or 'Create service connection')"
  echo "  3. Select 'Azure Resource Manager'"
  echo "  4. Select 'Workload Identity federation (automatic)'"
  echo "  5. Configure:"
  echo "     - Subscription: ${EXPECTED_SUBSCRIPTION_NAME}"
  echo "     - Service connection name: ${SERVICE_CONNECTION_NAME}"
  echo "     - Check box for Security > Grant access permission to all pipelines"
  echo "  6. Click 'Save'"
  echo
  echo "After creating the service connection, re-run this script."
  exit 1
fi

echo "[OK] Service connection found"
echo "       Service connection ID: ${SERVICE_ENDPOINT_ID}"
echo

# Verify it uses workload identity federation
SC_DETAILS=$(az devops service-endpoint show \
  --id "${SERVICE_ENDPOINT_ID}" \
  --organization "${AZDO_ORG_URL}" \
  --project "${AZDO_PROJECT_NAME}")

# Extract authentication scheme (remove all whitespace and newlines first)
AUTH_SCHEME=$(echo "${SC_DETAILS}" | tr -d '\n\r\t ' | grep -o '"scheme":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$AUTH_SCHEME" ]]; then
  echo "[ERROR] Unable to determine authentication scheme from service connection"
  echo "[DEBUG] Service connection details:"
  echo "${SC_DETAILS}"
  exit 1
fi

if [[ "$AUTH_SCHEME" != "WorkloadIdentityFederation" ]]; then
  echo "[ERROR] Service connection exists but is not using Workload Identity Federation"
  echo "        Current authentication: ${AUTH_SCHEME}"
  echo "        Please recreate using Workload Identity Federation (automatic)"
  exit 1
fi

echo "[OK] Service connection uses Workload Identity Federation"
echo

# Extract app ID for RBAC assignment
APP_ID=$(echo "${SC_DETAILS}" | tr -d '\n\r\t ' | grep -o '"serviceprincipalid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
  echo "[ERROR] Unable to retrieve application ID from service connection"
  exit 1
fi

echo "[OK] Application ID retrieved: ${APP_ID}"
echo

# Get service principal object ID for RBAC
SP_OBJECT_ID=$(az ad sp show --id "${APP_ID}" --query id -o tsv)

if [[ -z "$SP_OBJECT_ID" ]]; then
  echo "[ERROR] Unable to retrieve service principal object ID"
  exit 1
fi

echo "[OK] Service principal object ID: ${SP_OBJECT_ID}"
echo

# -------------------------------------------------------------------
# PRE-FLIGHT: PERMISSIONS CHECK
# -------------------------------------------------------------------

echo "[INFO] Verifying required permissions for RBAC assignment"
echo "[WARN] This script requires:"
echo "       - Azure: Owner or User Access Administrator on subscription"
echo
read -p "Do you have these permissions active? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "[ERROR] Required permissions not confirmed. Exiting."
  exit 1
fi

echo "[OK] Permissions confirmed"
echo

# -------------------------------------------------------------------
# CHECK EXISTING RBAC ASSIGNMENT
# -------------------------------------------------------------------

echo "[INFO] Checking for existing RBAC assignment"

EXISTING_ASSIGNMENT=$(az role assignment list \
  --assignee "${SP_OBJECT_ID}" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT_NAME}" \
  --query "[0].id" \
  -o tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_ASSIGNMENT" ]]; then
  echo "[OK] RBAC assignment already exists"
  echo "       Assignment ID: ${EXISTING_ASSIGNMENT}"
  echo "       Skipping RBAC assignment"
  RBAC_SKIPPED=true
else
  echo "[OK] No existing RBAC assignment found"
  RBAC_SKIPPED=false
fi

echo

# -------------------------------------------------------------------
# RBAC: TERRAFORM STATE ACCESS ONLY
# -------------------------------------------------------------------

if [[ "$RBAC_SKIPPED" == "false" ]]; then
  echo "[INFO] Assigning RBAC for Terraform remote state access"
  echo "[INFO] Scope: Storage account only (least privilege)"

  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT_NAME}" \
    >/dev/null

  echo "[OK] RBAC assignment complete"
  echo
fi

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo "[OK] Service connection configuration complete"
echo
echo "Service connection name:  ${SERVICE_CONNECTION_NAME}"
echo "Service connection ID:    ${SERVICE_ENDPOINT_ID}"
echo "Application ID:           ${APP_ID}"
echo "Service principal ID:     ${SP_OBJECT_ID}"
echo "Tenant ID:                ${EXPECTED_TENANT_ID}"
echo "Subscription ID:          ${SUBSCRIPTION_ID}"
echo
echo "Authentication:           Workload Identity Federation (OIDC)"
echo "RBAC scope:               Terraform state storage account"
echo "RBAC status:              $(if [[ "$RBAC_SKIPPED" == "true" ]]; then echo "Already configured"; else echo "Newly assigned"; fi)"
echo
echo "NOTE: Additional RBAC permissions (e.g., Management Group Contributor)"
echo "      must be granted separately based on project requirements."
echo "      See scripts/scaffolding/ for project-specific setup."
echo
