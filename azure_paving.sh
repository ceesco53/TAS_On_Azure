#!/usr/bin/env bash

function create_rg(){
  az group create -l "$LOCATION" -n "$RESOURCE_GROUP"
}

function create_tas_sg(){
  echo "Creating TAS network security group and access rules..."
  az network nsg create --name tas-nsg \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"

  az network nsg rule create --name ssh \
  --nsg-name tas-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 100 \
  --destination-port-range '22'

  az network nsg rule create --name http \
  --nsg-name tas-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 200 \
  --destination-port-range '80'

  az network nsg rule create --name https \
  --nsg-name tas-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 300 \
  --destination-port-range '443'

  az network nsg rule create --name diego-ssh \
  --nsg-name tas-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 400 \
  --destination-port-range '2222'
}

function create_opsman_sg(){
  echo "Creating Ops manager network security group and access rules..."
  az network nsg create --name opsmgr-nsg \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"

  az network nsg rule create --name http \
  --nsg-name opsmgr-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 100 \
  --destination-port-range 80

  az network nsg rule create --name https \
  --nsg-name opsmgr-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 200 \
  --destination-port-range 443

  az network nsg rule create --name ssh \
  --nsg-name opsmgr-nsg --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --priority 300 \
  --destination-port-range 22
}

function create_tas_vnet(){
  echo "Creating TAS virtual network..."
  az network vnet create --name tas-virtual-network \
  --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --address-prefixes 10.0.0.0/16
}

function create_subnets(){
  echo "Creating subnets..."
  az network vnet subnet create --name tas-infrastructure-subnet \
  --vnet-name tas-virtual-network \
  --resource-group "$RESOURCE_GROUP" \
  --address-prefix 10.0.4.0/26 \
  --network-security-group tas-nsg
  az network vnet subnet create --name tas-runtime-subnet \
  --vnet-name tas-virtual-network \
  --resource-group "$RESOURCE_GROUP" \
  --address-prefix 10.0.12.0/22 \
  --network-security-group tas-nsg
  az network vnet subnet create --name tas-services-subnet \
  --vnet-name tas-virtual-network \
  --resource-group "$RESOURCE_GROUP" \
  --address-prefix 10.0.8.0/22 \
  --network-security-group tas-nsg
}

function create_bosh_storage_account(){
  echo "Creating Bosh storage account..."
  az storage account create --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_LRS \
  --location "$LOCATION"
}

function create_storage(){
  az storage container create --name opsmanager \
  --connection-string "$CONNECTION_STRING"
  az storage container create --name bosh \
  --connection-string "$CONNECTION_STRING"
  az storage container create --name stemcell --public-access blob \
  --connection-string "$CONNECTION_STRING"

  az storage table create --name stemcells \
  --connection-string "$CONNECTION_STRING"
}

function create_lbs(){
  echo "Creating Load Balancers..."

  az network lb create --name pcf-lb \
  --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --backend-pool-name pcf-lb-be-pool --frontend-ip-name pcf-lb-fe-ip \
  --public-ip-address pcf-lb-ip --public-ip-address-allocation Static \
  --sku Standard

  az network lb probe create --lb-name pcf-lb \
  --name http8080 --resource-group "$RESOURCE_GROUP" \
  --protocol Http --port 8080 --path health

  az network lb rule create --lb-name pcf-lb \
  --name http --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --frontend-port 80 \
  --backend-port 80 --frontend-ip-name pcf-lb-fe-ip \
  --backend-pool-name pcf-lb-be-pool \
  --probe-name http8080

  az network lb rule create --lb-name pcf-lb \
  --name https --resource-group "$RESOURCE_GROUP" \
  --protocol Tcp --frontend-port 443 \
  --backend-port 443 --frontend-ip-name pcf-lb-fe-ip \
  --backend-pool-name pcf-lb-be-pool \
  --probe-name http8080
}

function create_storage_containers(){
  CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" | cut -c 24- | sed 's/"$//')

  echo "Creating other storage accounts..."
  STORAGE_TYPE="Premium_LRS"
  STORAGE_NAME1="${RESOURCE_GROUP}storage4tas1"
  STORAGE_NAME2="${RESOURCE_GROUP}storage4tas2"
  STORAGE_NAME3="${RESOURCE_GROUP}storage4tas3"

  az storage account create --name "$STORAGE_NAME1" \
  --resource-group "$RESOURCE_GROUP" --sku $STORAGE_TYPE \
  --kind Storage --location $LOCATION

  CONNECTION_STRING1=$(az storage account show-connection-string --name "$STORAGE_NAME1" --resource-group "$RESOURCE_GROUP" | cut -c 24- | sed 's/"$//')

  az storage container create --name bosh \
  --connection-string "$CONNECTION_STRING1"
  az storage container create --name stemcell \
  --connection-string "$CONNECTION_STRING1"

  az storage account create --name "$STORAGE_NAME2" \
  --resource-group "$RESOURCE_GROUP" --sku $STORAGE_TYPE \
  --kind Storage --location $LOCATION

  CONNECTION_STRING2=$(az storage account show-connection-string --name "$STORAGE_NAME2" --resource-group "$RESOURCE_GROUP" | cut -c 24- | sed 's/"$//')

  az storage container create --name bosh \
  --connection-string "$CONNECTION_STRING2"
  az storage container create --name stemcell \
  --connection-string "$CONNECTION_STRING2"

  az storage account create --name "$STORAGE_NAME3" \
  --resource-group "$RESOURCE_GROUP" --sku $STORAGE_TYPE \
  --kind Storage --location $LOCATION

  CONNECTION_STRING3=$(az storage account show-connection-string --name "$STORAGE_NAME3" --resource-group "$RESOURCE_GROUP" | cut -c 24- | sed 's/"$//')

  az storage container create --name bosh \
  --connection-string "$CONNECTION_STRING3"
  az storage container create --name stemcell \
  --connection-string "$CONNECTION_STRING3"
}

pave_azure(){
  # Delegation
  create_rg
  create_tas_sg
  create_opsman_sg
  create_tas_vnet
  create_subnets
  create_bosh_storage_account
  create_storage
  create_lbs
  create_storage_containers
}

#depave_azure(){
#  delete_rg
#  delete_tas_sg
#  delete_opsman_sg
#  delete_tas_vnet
#  delete_subnets
#  delete_bosh_storage_account
#  delete_storage
#  delete_lbs
#}