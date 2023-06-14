#!/usr/bin/env bash

function azure_login(){

  az cloud set --name AzureCloud

  echo "Log in with your VMware AD account on your browser"
  az login

  SELECTED="$(az account list | grep -v "\-\-" | grep -v Name | fzf)"

  SUBSCRIPTION_ID=$(echo "$SELECTED" | cut -f3 -w)
  TENANT_ID=$(echo "$SELECTED" | cut -f4 -w)

  SP_NAME="http://BoshAzure$RESOURCE_GROUP"
  DOMAIN="test.vmware.com"
  az account set --subscription "$SUBSCRIPTION_ID"
  az ad app create --display-name "$SP_DISPLAY_NAME" \
  --web-home-page-url 'http://BOSHAzureCPI' \
  --identifier-uris "$SP_NAME.$DOMAIN"

  APPLICATION_ID=$(az ad app list --identifier-uri "$SP_NAME".$DOMAIN -o tsv | cut -f2 -w)

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

  SP_PASSWORD=$(az ad sp credential reset --id "$APPLICATION_ID" -o json | jq -r .password)
  echo "SP_PASSWORD is $SP_PASSWORD"

  echo "Creating resource group..."
  if [ $GSS_TEAM = "east" ]; then
      LOCATION="eastus"
  else
      LOCATION="westus"
  fi
  STORAGE_NAME="${RESOURCE_GROUP}4tas"
}
