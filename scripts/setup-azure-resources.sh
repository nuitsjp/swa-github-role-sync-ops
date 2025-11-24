#!/usr/bin/env bash
set -euo pipefail

# Usage: ./setup-azure-resources.sh <owner> <repository>
# Example: ./setup-azure-resources.sh nuitsjp swa-github-role-sync-ops

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <owner> <repository>"
  echo "Example: $0 nuitsjp swa-github-role-sync-ops"
  exit 1
fi

OWNER="$1"
REPO_NAME="$2"
GITHUB_REPO="${OWNER}/${REPO_NAME}"
LOCATION="japaneast"
SWA_LOCATION="eastasia"

# Naming convention based on Azure Cloud Adoption Framework
RG_NAME="rg-${REPO_NAME}-prod"
SWA_NAME="stapp-${REPO_NAME}-prod"
IDENTITY_NAME="id-${REPO_NAME}-prod"
FED_CRED_NAME="fc-github-actions-main"

echo "=== Azure Resource Setup for ${REPO_NAME} ==="
echo "Resource Group: ${RG_NAME}"
echo "Static Web App: ${SWA_NAME}"
echo "Managed Identity: ${IDENTITY_NAME}"
echo "GitHub Repo: ${GITHUB_REPO}"
echo ""

# 1. Create Resource Group
echo "[1/6] Creating Resource Group..."
az group create --name "$RG_NAME" --location "$LOCATION" -o none
echo "  Created: ${RG_NAME}"

# 2. Create Static Web App (Standard SKU required for role sync)
echo "[2/6] Creating Static Web App..."
az staticwebapp create \
  --name "$SWA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$SWA_LOCATION" \
  --sku Standard \
  -o none
DEFAULT_HOSTNAME=$(az staticwebapp show --name "$SWA_NAME" --resource-group "$RG_NAME" --query defaultHostname -o tsv)
echo "  Created: ${SWA_NAME}"
echo "  Hostname: ${DEFAULT_HOSTNAME}"

# 3. Create Managed Identity
echo "[3/6] Creating Managed Identity..."
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  -o none
CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RG_NAME" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RG_NAME" --query principalId -o tsv)
echo "  Created: ${IDENTITY_NAME}"
echo "  Client ID: ${CLIENT_ID}"

# 4. Create OIDC Federated Credential
echo "[4/6] Creating Federated Credential..."
az identity federated-credential create \
  --name "$FED_CRED_NAME" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RG_NAME" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${GITHUB_REPO}:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange" \
  -o none
echo "  Created: ${FED_CRED_NAME}"

# 5. Assign Contributor role to Managed Identity
echo "[5/6] Assigning RBAC role..."
SWA_ID=$(az staticwebapp show --name "$SWA_NAME" --resource-group "$RG_NAME" --query id -o tsv)
# Wait for identity to propagate in Azure AD
sleep 15
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "$SWA_ID" \
  -o none
echo "  Assigned Contributor role to ${IDENTITY_NAME}"

# 6. Register GitHub Secrets
echo "[6/6] Registering GitHub Secrets..."
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --repo "$GITHUB_REPO"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$GITHUB_REPO"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$GITHUB_REPO"

echo "  AZURE_CLIENT_ID: ${CLIENT_ID}"
echo "  AZURE_TENANT_ID: ${TENANT_ID}"
echo "  AZURE_SUBSCRIPTION_ID: ${SUBSCRIPTION_ID}"

echo ""
echo "=== Setup Complete ==="
echo "SWA URL: https://${DEFAULT_HOSTNAME}"
