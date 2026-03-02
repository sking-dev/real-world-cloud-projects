#!/usr/bin/env bash

set -euo pipefail

echo "[INFO] Creating Azure DevOps pipeline identity (workload identity federation)"
echo

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# Azure / Entra ID
EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

EXPECTED_SUBSCRIPTION_NAME="sub-myorg-azuregovernance-prod"
SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Azure DevOps
AZDO_ORG_NAME="myorg"
AZDO_PROJECT_NAME="myorg-azuregovernance"

# Identity naming (aligned to org-wide convention)
APP_DISPLAY_NAME="az-sub-myorg-azuregovernance-spn-prod"
FEDERATED_CREDENTIAL_NAME="azdo-azuregovernance-project"

# Terraform state (from Script 02)
STATE_RESOURCE_GROUP_NAME="rg-uks-azuregovernance-tfstate-prod"
STATE_STORAGE_ACCOUNT_NAME="stmyorgtfstatexxxxxx"

# -------------------------------------------------------------------
# PRE-FLIGHT CHECKS
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

echo "[OK] Tenant verified"
echo

# -------------------------------------------------------------------
# SUBSCRIPTION VALIDATION
# -------------------------------------------------------------------

echo "[INFO] Verifying target subscription"

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

echo "[OK] Subscription verified: $ACTUAL_SUBSCRIPTION_NAME"
echo

# -------------------------------------------------------------------
# FAIL-FAST: CHECK FOR EXISTING APP
# -------------------------------------------------------------------

echo "[INFO] Checking for existing application registration"

EXISTING_APP_ID=$(az ad app list \
  --display-name "$APP_DISPLAY_NAME" \
  --query "[0].appId" \
  -o tsv)

if [[ -n "$EXISTING_APP_ID" ]]; then
  echo "[ERROR] Application already exists: $APP_DISPLAY_NAME"
  echo "        App ID: $EXISTING_APP_ID"
  echo "        Script is designed to fail-fast to avoid ambiguity."
  exit 1
fi

echo "[OK] No existing application found"
echo

# -------------------------------------------------------------------
# CREATE APP REGISTRATION
# -------------------------------------------------------------------

echo "[INFO] Creating Entra ID application"

APP_ID=$(az ad app create \
  --display-name "$APP_DISPLAY_NAME" \
  --query appId \
  -o tsv)

echo "[OK] Application created"
echo "       App ID: $APP_ID"
echo

# -------------------------------------------------------------------
# CREATE SERVICE PRINCIPAL
# -------------------------------------------------------------------

echo "[INFO] Creating service principal"

SP_OBJECT_ID=$(az ad sp create \
  --id "$APP_ID" \
  --query id \
  -o tsv)

echo "[OK] Service principal created"
echo

# -------------------------------------------------------------------
# CREATE FEDERATED CREDENTIAL (AZDO PROJECT LEVEL)
# -------------------------------------------------------------------

echo "[INFO] Creating federated credential for Azure DevOps project"

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters @- <<EOF
{
  "name": "${FEDERATED_CREDENTIAL_NAME}",
  "issuer": "https://vstoken.dev.azure.com/${AZDO_ORG_NAME}",
  "subject": "sc://AzureDevOps/${AZDO_ORG_NAME}/${AZDO_PROJECT_NAME}",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

echo "[OK] Federated credential created"
echo

# -------------------------------------------------------------------
# RBAC: TERRAFORM STATE ACCESS ONLY
# -------------------------------------------------------------------

echo "[INFO] Assigning RBAC for Terraform remote state access"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT_NAME}"

echo "[OK] RBAC assignment complete"
echo

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo "[OK] Pipeline identity bootstrap complete"
echo
echo "Tenant ID:        $EXPECTED_TENANT_ID"
echo "Subscription ID:  $SUBSCRIPTION_ID"
echo "Application ID:   $APP_ID"
echo
echo "This identity uses workload identity federation (no secrets)."
echo "RBAC is intentionally limited to Terraform state access only."
echo "Script must be run by a platform engineer with Entra ID app admin rights."
