#!/usr/bin/env bash

# Fail fast: exit on error (-e), treat unset variables as errors (-u),
# and fail pipelines if any command in a pipeline fails (pipefail)
set -euo pipefail

echo "[INFO] Creating Azure resources for Terraform remote state (governance)"
echo

# -------------------------------------------------------------------
# DRY-RUN CONTROL
# -------------------------------------------------------------------

# Dry-run mode (can be set via environment variable)
DRY_RUN="${DRY_RUN:-false}"

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

EXPECTED_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
TARGET_SUBSCRIPTION_NAME="sub-myorg-azuregovernance-prod"

LOCATION="uksouth"
REGION_SHORT="uks"

RESOURCE_GROUP_NAME="rg-${REGION_SHORT}-azuregovernance-tfstate-prod"
STORAGE_ACCOUNT_PREFIX="stmyorgtfstate"
STATE_CONTAINER_NAME="terraform-state"

RANDOM_SUFFIX_LENGTH=6
SOFT_DELETE_RETENTION_DAYS=14

INCEPTION_DATE=$(date -u +"%Y%m%dT%H%M%SZ")

# JSON tags passed directly to ARM/Bicep (no jq dependency)
TAGS_JSON=$(cat <<EOF
{
  "ProjectName": "AzureGovernance",
  "Env": "prod",
  "DeployedBy": "BootstrapScript",
  "InceptionDate": "${INCEPTION_DATE}"
}
EOF
)

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

echo "[OK] Tenant verified: $CURRENT_TENANT_ID"
echo

# -------------------------------------------------------------------
# SUBSCRIPTION RESOLUTION
# -------------------------------------------------------------------

echo "[INFO] Resolving target subscription"

SUBSCRIPTION_ID=$(az account list \
  --only-show-errors \
  --query "[?name=='${TARGET_SUBSCRIPTION_NAME}'].id | [0]" \
  -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "[ERROR] Target subscription not found: $TARGET_SUBSCRIPTION_NAME"
  exit 1
fi

run az account set --subscription "$SUBSCRIPTION_ID"
az config set defaults.subscription="$SUBSCRIPTION_ID" >/dev/null

echo "[OK] Target subscription set: $TARGET_SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo

# -------------------------------------------------------------------
# RESOURCE GROUP
# -------------------------------------------------------------------

echo "[INFO] Ensuring resource group exists: $RESOURCE_GROUP_NAME"

RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP_NAME")

if [[ "$RG_EXISTS" == "false" ]]; then
  run az group create \
    --subscription "$SUBSCRIPTION_ID" \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags ProjectName=AzureGovernance Env=prod DeployedBy=BootstrapScript InceptionDate="$INCEPTION_DATE" \
    --output none
  echo "[OK] Resource group created"
else
  echo "[OK] Resource group already exists"
fi

if [[ "$RG_EXISTS" == "false" && "$DRY_RUN" == "false" ]]; then
  echo "[INFO] Waiting for resource group to become available..."
  sleep 10
fi

echo

# -------------------------------------------------------------------
# STORAGE ACCOUNT + CONTAINER
# -------------------------------------------------------------------

echo "[INFO] Ensuring storage account for Terraform state exists"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would ensure storage account exists with prefix: $STORAGE_ACCOUNT_PREFIX"
  echo "[DRY-RUN] Would apply tags: $TAGS_JSON"
  echo "[DRY-RUN] Would enable blob and container soft delete (${SOFT_DELETE_RETENTION_DAYS} days)"
  echo "[DRY-RUN] Would ensure blob container exists: $STATE_CONTAINER_NAME"
  echo
else
  EXISTING_STORAGE_ACCOUNT=$(az storage account list \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?starts_with(name, '${STORAGE_ACCOUNT_PREFIX}')].name | [0]" \
    -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING_STORAGE_ACCOUNT" ]]; then
    STORAGE_ACCOUNT_NAME="$EXISTING_STORAGE_ACCOUNT"
    echo "[OK] Reusing existing storage account: $STORAGE_ACCOUNT_NAME"
  else
    RANDOM_SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c "$RANDOM_SUFFIX_LENGTH" || true)
    STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_PREFIX}${RANDOM_SUFFIX}"

    echo "[INFO] Creating storage account: $STORAGE_ACCOUNT_NAME"

    # NOTE:
    # Storage account creation is performed via ARM/Bicep rather than
    # `az storage account create` due to a long-standing Azure CLI issue
    # where storage commands may fail with SubscriptionNotFound during
    # bootstrap, even when subscription context is correctly set.
    #
    # This is a deliberate, contained workaround. Revisit if/when Azure
    # CLI storage commands become reliable in this scenario.

    az deployment group create \
      --subscription "$SUBSCRIPTION_ID" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --template-file 02-create-storage-account.bicep \
      --parameters \
        storageAccountName="$STORAGE_ACCOUNT_NAME" \
        location="$LOCATION" \
        tags="$TAGS_JSON" \
      --output none

    echo "[OK] Storage account created"
    echo "[INFO] Waiting for storage account to become available..."
    sleep 10
  fi

  echo

  echo "[INFO] Ensuring storage account soft delete is enabled"

  az storage account blob-service-properties update \
    --subscription "$SUBSCRIPTION_ID" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --enable-delete-retention true \
    --delete-retention-days "$SOFT_DELETE_RETENTION_DAYS" \
    --enable-container-delete-retention true \
    --container-delete-retention-days "$SOFT_DELETE_RETENTION_DAYS" \
    --output none

  echo "[OK] Storage account soft delete configured"
  echo

  echo "[INFO] Ensuring blob container exists: $STATE_CONTAINER_NAME"

  STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --subscription "$SUBSCRIPTION_ID" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[0].value" \
    -o tsv)

  CONTAINER_EXISTS=$(az storage container exists \
    --subscription "$SUBSCRIPTION_ID" \
    --name "$STATE_CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_ACCOUNT_KEY" \
    --query "exists" \
    -o tsv)

  if [[ "$CONTAINER_EXISTS" == "false" ]]; then
    az storage container create \
      --subscription "$SUBSCRIPTION_ID" \
      --name "$STATE_CONTAINER_NAME" \
      --account-name "$STORAGE_ACCOUNT_NAME" \
      --account-key "$STORAGE_ACCOUNT_KEY" \
      --output none
    echo "[OK] Blob container created"
  else
    echo "[OK] Blob container already exists"
  fi
fi

echo

# -------------------------------------------------------------------
# SUMMARY
# -------------------------------------------------------------------

echo "[OK] Terraform remote state resources are ready"
echo
echo "       Subscription:     $TARGET_SUBSCRIPTION_NAME"
echo "       Resource Group:   $RESOURCE_GROUP_NAME"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "       Storage Account: (dry-run preview)"
else
  echo "       Storage Account: $STORAGE_ACCOUNT_NAME"
fi
echo "       Container:       $STATE_CONTAINER_NAME"
