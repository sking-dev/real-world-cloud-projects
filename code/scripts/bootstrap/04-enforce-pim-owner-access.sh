#!/usr/bin/env bash

set -euo pipefail

echo "[INFO] Enforcing PIM-only Owner access (removing static user Owners)"
echo

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# Azure
EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
EXPECTED_SUBSCRIPTION_NAME="sub-myorg-azuregovernance-prod"
SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Explicit break-glass accounts to preserve (UPNs)
BREAK_GLASS_UPNS=(
  "SubCreateAccount@organisation.com"
)

# -------------------------------------------------------------------
# PRE-FLIGHT: AZURE CONTEXT
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
# ENUMERATE STATIC USER OWNER ASSIGNMENTS
# -------------------------------------------------------------------

echo "[INFO] Enumerating static user Owner assignments"

mapfile -t USER_OWNER_ASSIGNMENTS < <(
  az role assignment list \
    --role Owner \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --query "[?principalType=='User'].[principalName,id]" \
    -o tsv
)

if [[ "${#USER_OWNER_ASSIGNMENTS[@]}" -eq 0 ]]; then
  echo "[INFO] No static user Owner assignments found. Nothing to do."
  exit 0
fi

echo "[INFO] Found static user Owner assignments:"
for entry in "${USER_OWNER_ASSIGNMENTS[@]}"; do
  echo "  - ${entry%%$'\t'*}"
done
echo

# -------------------------------------------------------------------
# SAFETY CHECK: VERIFY BREAK-GLASS ACCOUNTS ARE PRESENT
# -------------------------------------------------------------------

echo "[INFO] Verifying break-glass Owner assignments exist"

for bg in "${BREAK_GLASS_UPNS[@]}"; do
  FOUND=false
  for entry in "${USER_OWNER_ASSIGNMENTS[@]}"; do
    UPN="${entry%%$'\t'*}"
    if [[ "$UPN" == "$bg" ]]; then
      FOUND=true
      break
    fi
  done

  if [[ "$FOUND" == false ]]; then
    echo "[ERROR] Break-glass account not found as static Owner: ${bg}"
    echo "        Aborting to avoid accidental lock-out."
    exit 1
  fi
done

echo "[OK] All break-glass accounts verified"
echo

# -------------------------------------------------------------------
# REMOVE STATIC USER OWNER ASSIGNMENTS (EXCEPT BREAK-GLASS)
# -------------------------------------------------------------------

for entry in "${USER_OWNER_ASSIGNMENTS[@]}"; do
  UPN="${entry%%$'\t'*}"
  ASSIGNMENT_ID="${entry##*$'\t'}"

  if [[ " ${BREAK_GLASS_UPNS[*]} " =~ " ${UPN} " ]]; then
    echo "[INFO] Preserving break-glass Owner assignment for ${UPN}"
    continue
  fi

  echo "[INFO] Removing static Owner assignment for ${UPN}"

  az role assignment delete \
    --ids "$ASSIGNMENT_ID"
done

echo
echo "[OK] Static Owner cleanup complete"

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo
echo "[OK] Subscription now enforces PIM-only Owner access"
echo
echo "Preserved break-glass accounts:"
for bg in "${BREAK_GLASS_UPNS[@]}"; do
  echo "  - ${bg}"
done

echo
echo "Any remaining Owner access must be activated via PIM."
