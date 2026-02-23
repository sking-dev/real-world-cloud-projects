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

# Expected number of subscriptions (sanity check)
EXPECTED_SUB_COUNT=4

# Expected environment suffixes (light guardrail; warnings only)
EXPECTED_ENV_SUFFIXES=(
  "dev"
  "uat"
  "pp"
  "prod"
)

# -------------------------------------------------------------------
# INTENT CONFIRMATION
# -------------------------------------------------------------------

echo "[INFO] Subscriptions supplied for validation:"
for SUB_NAME in "${SUBSCRIPTION_NAMES[@]}"; do
  echo "       - $SUB_NAME"
done
echo

if [[ "${#SUBSCRIPTION_NAMES[@]}" -ne "$EXPECTED_SUB_COUNT" ]]; then
  echo "[ERROR] Expected $EXPECTED_SUB_COUNT subscriptions but found ${#SUBSCRIPTION_NAMES[@]}"
  exit 1
fi

echo "[OK] Subscription count matches expected value: $EXPECTED_SUB_COUNT"
echo

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
# ENVIRONMENT SUFFIX GUARDRAILS (WARNING ONLY)
# -------------------------------------------------------------------

echo "[INFO] Performing environment suffix sanity checks"

FOUND_ENV_SUFFIXES=()

for SUB_NAME in "${SUBSCRIPTION_NAMES[@]}"; do
  ENV_SUFFIX="${SUB_NAME##*-}"
  FOUND_ENV_SUFFIXES+=("$ENV_SUFFIX")
done

for EXPECTED_ENV in "${EXPECTED_ENV_SUFFIXES[@]}"; do
  if [[ ! " ${FOUND_ENV_SUFFIXES[*]} " =~ " ${EXPECTED_ENV} " ]]; then
    echo "[WARN] Expected environment suffix not found: $EXPECTED_ENV"
  fi
done

for FOUND_ENV in "${FOUND_ENV_SUFFIXES[@]}"; do
  if [[ ! " ${EXPECTED_ENV_SUFFIXES[*]} " =~ " ${FOUND_ENV} " ]]; then
    echo "[WARN] Unexpected environment suffix found: $FOUND_ENV"
  fi
done

echo "[OK] Environment suffix sanity checks completed"
echo

# -------------------------------------------------------------------
# DOMAIN CONSISTENCY GUARDRAIL (WARNING ONLY)
# -------------------------------------------------------------------

echo "[INFO] Performing domain consistency sanity check"

FOUND_DOMAINS=()

for SUB_NAME in "${SUBSCRIPTION_NAMES[@]}"; do
  # Strip leading 'sub-' if present, then strip trailing '-<env>'
  NAME_CORE="${SUB_NAME#sub-}"
  DOMAIN="${NAME_CORE%-*}"
  FOUND_DOMAINS+=("$DOMAIN")
done

UNIQUE_DOMAINS=$(printf "%s\n" "${FOUND_DOMAINS[@]}" | sort -u)
DOMAIN_COUNT=$(echo "$UNIQUE_DOMAINS" | wc -l | tr -d ' ')

if [[ "$DOMAIN_COUNT" -gt 1 ]]; then
  echo "[WARN] Multiple domain components detected in subscription names:"
  echo "$UNIQUE_DOMAINS" | sed 's/^/       - /'
else
  echo "[OK] Subscription domain is consistent: $UNIQUE_DOMAINS"
fi

echo

# -------------------------------------------------------------------
# RESOLVE SUBSCRIPTION NAMES → IDS
# -------------------------------------------------------------------

echo "[INFO] Resolving subscription names to IDs"

SUBSCRIPTIONS=()

for SUB_NAME in "${SUBSCRIPTION_NAMES[@]}"; do
  MATCH_COUNT=$(az account list \
    --only-show-errors \
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
    --only-show-errors \
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
