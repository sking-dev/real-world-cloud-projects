# Script: 01-verify-subscriptions-ready.sh
# Purpose: Validate access and prerequisites before any bootstrap actions
# Expected order: Run first

#!/usr/bin/env bash

# Fail fast: exit on error (-e), treat unset variables as errors (-u),
# and fail pipelines if any command in a pipeline fails (pipefail)
set -euo pipefail

echo "[INFO] Verifying Azure subscription readiness for IaC onboarding"
echo

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# Expected Azure AD tenant ID (guards against accidental execution
# in the wrong tenant)
EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Explicit list of subscription names expected to be onboarded.
# Names are resolved to IDs and validated before use.
SUBSCRIPTION_NAMES=(
  "sub-myorg-azuregovernance-dev"
  "sub-myorg-azuregovernance-uat"
  "sub-myorg-azuregovernance-pp"
  "sub-myorg-azuregovernance-prod"
)

# -------------------------------------------------------------------
# PRE-FLIGHT CHECKS
# -------------------------------------------------------------------

echo "[INFO] Checking Azure CLI authentication"
az account show >/dev/null

CURRENT_TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ "$CURRENT_TENANT_ID" != "$EXPECTED_TENANT_ID" ]]; then
  echo "[ERROR] Logged into wrong tenant"
  echo "        Expected: $EXPECTED_TENANT_ID"
  echo "        Actual:   $CURRENT_TENANT_ID"
  exit 1
fi

echo "[OK] Tenant verified: $CURRENT_TENANT_ID"
echo

# Get object ID of the signed-in user (assumed to be a platform engineer)
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# -------------------------------------------------------------------
# RESOLVE SUBSCRIPTION NAMES → IDS
# -------------------------------------------------------------------

echo "[INFO] Resolving subscription names to IDs"

SUBSCRIPTIONS=()

for SUB_NAME in "${SUBSCRIPTION_NAMES[@]}"; do
  MATCH_COUNT=$(az account list \
    --query "[?name=='${SUB_NAME}'] | length(@)" \
    -o tsv)

  if [[ "$MATCH_COUNT" -eq 0 ]]; then
    echo "[ERROR] Subscription not found: $SUB_NAME"
    exit 1
  fi

  if [[ "$MATCH_COUNT" -gt 1 ]]; then
    echo "[ERROR] Multiple subscriptions found with name: $SUB_NAME"
    echo "        Subscription names must be unique"
    exit 1
  fi

  SUB_ID=$(az account list \
    --query "[?name=='${SUB_NAME}'].id | [0]" \
    -o tsv)

  echo "[OK] $SUB_NAME -> $SUB_ID"
  SUBSCRIPTIONS+=("$SUB_ID")
done

echo

# -------------------------------------------------------------------
# ACCESS VALIDATION
# -------------------------------------------------------------------

echo "[INFO] Verifying Owner access on target subscriptions"

for SUB_ID in "${SUBSCRIPTIONS[@]}"; do
  echo "[INFO] Checking subscription $SUB_ID"

  # Confirm subscription is accessible
  az account show --subscription "$SUB_ID" >/dev/null

  OWNER_ASSIGNMENTS=$(az role assignment list \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --subscription "$SUB_ID" \
    --role Owner \
    --query "length(@)" \
    -o tsv)

  if [[ "$OWNER_ASSIGNMENTS" -eq 0 ]]; then
    echo "[ERROR] Current user does not have Owner role on subscription $SUB_ID"
    echo "        Ensure temporary Owner access has been granted before proceeding"
    exit 1
  fi

  echo "[OK] Owner role confirmed on $SUB_ID"
done

echo
echo "[OK] All subscriptions verified"
echo "[OK] Safe to proceed with bootstrap scripts"
