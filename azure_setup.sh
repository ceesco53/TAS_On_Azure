#!/usr/bin/env bash

function azure_login(){

  az cloud set --name AzureCloud

  echo "Log in with your VMware AD account on your browser"
  az login

  SELECTED="$(az account list | grep -v "\-\-" | grep -v Name | fzf)"

  SUBSCRIPTION_ID=$(echo "$SELECTED" | cut -f3 -w)
  TENANT_ID=$(echo "$SELECTED" | cut -f4 -w)

  read -p 'Please enter the Opsman exact version and build. You can find that info here https://network.pivotal.io/products/ops-manager/#/releases (Example: 2.10.58-build.1011) : ' OPSMAN_VERSION
  read -p 'Please enter the TAS version you would like to install (Example: 2.11.40): ' TAS_VERSION
  read -p 'Please enter your Pivnet API refresh token. If you do NOT have one: Log into pivnet > edit profile > request new refresh token): ' REFRESH_TOKEN
  read -p 'Which support team are you a part of? (east or west): ' GSS_TEAM
  read -p 'Please enter a unique name for your resource group - all lowercase (Example: jsmith): ' RESOURCE_GROUP
  read -sp 'Please enter a new password for Opsman: ' SP_SECRET
  echo ''
  read -sp 'Please enter your Mac admin password: ' MAC_ADMIN

  # You should only have one GSS subscription but just in case
#  SUBSCRIPTION_ID=$(az account list | grep -i "$GSS_TEAM" -B 3 | grep id | cut -c 12-47)
#  TENANT_ID=$(az account list | grep -i "$GSS_TEAM" -A 2 | grep tenantId | cut -c 18-53)
  SP_NAME="http://BoshAzure$RESOURCE_GROUP"
  DOMAIN="test.vmware.com"
  az account set --subscription "$SUBSCRIPTION_ID"
  az ad app create --display-name "Service Principal for BOSH" \
  --web-home-page-url "http://BOSHAzureCPI" \
  --identifier-uris "$SP_NAME.$DOMAIN"

  APPLICATION_ID=$(az ad app list --identifier-uri "$SP_NAME".$DOMAIN | grep appId | cut -c 15-50)

  echo "Creating a Service Principal..."
  az ad sp create --id "$APPLICATION_ID"

  echo "Sleeping 1 minute"
  sleep 60

  echo "Assigning your Service Principal the Owner role..."
  az role assignment create --assignee "$SP_NAME".$DOMAIN \
  --role "Owner" --scope /subscriptions/"$SUBSCRIPTION_ID"

  az provider register --namespace Microsoft.Storage
  az provider register --namespace Microsoft.Network
  az provider register --namespace Microsoft.Compute

  echo "Creating resource group..."
  if [ $GSS_TEAM = "east" ]; then
      LOCATION="eastus"
  else
      LOCATION="westus"
  fi
  STORAGE_NAME="${RESOURCE_GROUP}storage4tas"
}

azure_login
