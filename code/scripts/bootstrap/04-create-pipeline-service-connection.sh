#!/usr/bin/env bash

set -euo pipefail

echo "[INFO] Creating Azure DevOps service connection (Workload Identity Federation)"
echo

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# Azure
EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
EXPECTED_SUBSCRIPTION_NAME="sub-myorg-azuregovernance-liv"
SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Azure DevOps
AZDO_ORG_NAME="myorg"
AZDO_PROJECT_NAME="azuregovernance"

# Identity (from Script 03)
SPN_DISPLAY_NAME="az-sub-myorg-azuregovernance-spn-liv"

# Service connection naming convention:
# Service connection name == SPN display name
SERVICE_CONNECTION_NAME="${SPN_DISPLAY_NAME}"

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
  --defaults organization="https://dev.azure.com/${AZDO_ORG_NAME}" \
  project="${AZDO_PROJECT_NAME}"

# Simple call to ensure auth is valid
az devops project show \
  --project "${AZDO_PROJECT_NAME}" \
  --organization "https://dev.azure.com/${AZDO_ORG_NAME}" \
  >/dev/null

echo "[OK] Azure DevOps context verified"
echo

# -------------------------------------------------------------------
# FAIL-FAST: CHECK FOR EXISTING SERVICE CONNECTION
# -------------------------------------------------------------------

echo "[INFO] Checking for existing service connection"

EXISTING_SC_ID=$(az devops service-endpoint list \
  --query "[?name=='${SERVICE_CONNECTION_NAME}'].id | [0]" \
  -o tsv)

if [[ -n "$EXISTING_SC_ID" ]]; then
  echo "[ERROR] Service connection already exists: $SERVICE_CONNECTION_NAME"
  echo "        Service connection ID: $EXISTING_SC_ID"
  echo "        Script is designed to fail-fast to avoid ambiguity."
  exit 1
fi

echo "[OK] No existing service connection found"
echo

# -------------------------------------------------------------------
# RESOLVE SPN APPLICATION ID
# -------------------------------------------------------------------

echo "[INFO] Resolving application ID for SPN"

APP_ID=$(az ad app list \
  --display-name "$SPN_DISPLAY_NAME" \
  --query "[0].appId" \
  -o tsv)

if [[ -z "$APP_ID" ]]; then
  echo "[ERROR] Unable to resolve application ID for SPN: $SPN_DISPLAY_NAME"
  echo "        Ensure Script 03 has completed successfully."
  exit 1
fi

echo "[OK] SPN application ID resolved"
echo "       App ID: $APP_ID"
echo

# -------------------------------------------------------------------
# CREATE SERVICE CONNECTION VIA REST API
# (Workload Identity Federation is not currently supported by the Azure DevOps CLI)
# -------------------------------------------------------------------

echo "[INFO] Creating Azure Resource Manager service connection via REST API"

SERVICE_ENDPOINT_PAYLOAD=$(cat <<EOF
{
  "name": "${SERVICE_CONNECTION_NAME}",
  "type": "azurerm",
  "authorization": {
    "scheme": "WorkloadIdentityFederation",
    "parameters": {
      "tenantid": "${EXPECTED_TENANT_ID}",
      "serviceprincipalid": "${APP_ID}"
    }
  },
  "data": {
    "subscriptionId": "${SUBSCRIPTION_ID}",
    "subscriptionName": "${EXPECTED_SUBSCRIPTION_NAME}",
    "environment": "AzureCloud",
    "scopeLevel": "Subscription"
  },
  "isShared": true
}
EOF
)

az devops invoke \
  --area serviceendpoint \
  --resource endpoints \
  --route-parameters project="${AZDO_PROJECT_NAME}" \
  --http-method POST \
  --in-file <(echo "${SERVICE_ENDPOINT_PAYLOAD}") \
  >/dev/null

echo "[OK] Service connection created"
echo

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo "[OK] Azure DevOps service connection bootstrap complete"
echo
echo "Service connection name: ${SERVICE_CONNECTION_NAME}"
echo "Subscription:            ${EXPECTED_SUBSCRIPTION_NAME}"
echo "Authentication:          Workload Identity Federation (OIDC)"
echo
echo "The service connection is project-scoped and uses the federated pipeline identity."
