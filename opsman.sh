#!/usr/bin/env bash

# Create a keypair
if [ -d "$HOME/.ssh/azurekeys" ] && [ -f "$HOME/.ssh/azurekeys/opsman" ]; then
    echo "Key pair already exists in ~/.ssh/azurekeys"
else
    echo "Creating a key pair in ~/.ssh/azurekeys"
    mkdir -p ~/.ssh/azurekeys
    ssh-keygen -t rsa -f ~/.ssh/azurekeys/opsman -C ubuntu -N ""
fi

get_status() {
  echo $(az storage blob show --name opsman-"$OPSMAN_VERSION".vhd --connection-string "$CONNECTION_STRING" --container-name opsmanager -o json | jq -r '.properties.copy.status')
}

blob_exists() {
  az storage blob show --name opsman-"$OPSMAN_VERSION".vhd --connection-string "$CONNECTION_STRING" --container-name opsmanager -o json 2>/dev/null || true
}

opsman_authentication_setup()
{
  cat <<EOF | jq -c .
{
    "setup": {
    "decryption_passphrase": "$SP_SECRET",
    "decryption_passphrase_confirmation": "$SP_SECRET",
    "eula_accepted": "true",
    "identity_provider": "internal",
    "admin_user_name": "admin",
    "admin_password": "$SP_SECRET",
    "admin_password_confirmation": "$SP_SECRET",
    "http_proxy": "",
    "https_proxy": "",
    "no_proxy": ""
  }
}
EOF
}

function boot_opsman(){
  # Boot Ops Manager
  echo "copying image to storage..."
  OPS_MAN_IMAGE_URL=https://opsmanager$LOCATION.blob.core.windows.net/images/ops-manager-$OPSMAN_VERSION.vhd

  status=$(blob_exists)

  if [[ $status =~ '"status":' ]]; then
    echo "Blobstore already exists."
  else
    az storage blob copy start --source-uri "$OPS_MAN_IMAGE_URL" \
    --connection-string "$CONNECTION_STRING" \
    --destination-container opsmanager \
    --destination-blob opsman-"$OPSMAN_VERSION".vhd
  fi

  # Create a public IP for Ops Manager
  az network public-ip create --name ops-manager-ip \
  --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --allocation-method Static

  # Create a network interface for Ops Manager
  az network nic create --vnet-name tas-virtual-network \
  --subnet tas-infrastructure-subnet --network-security-group opsmgr-nsg \
  --private-ip-address 10.0.4.4 \
  --public-ip-address ops-manager-ip \
  --resource-group "$RESOURCE_GROUP" \
  --name opsman-nic --location "$LOCATION"

  CPSTATUS="copying"

  while [ "$CPSTATUS" != "success" ]; do
      CPSTATUS="$(get_status)"
      echo "blob is still copying..."
      sleep 30
  done

  echo "Transfer complete"
}

function create_opsman_vm(){
  az image create --resource-group "$RESOURCE_GROUP" \
  --name opsman-"$OPSMAN_VERSION" \
  --source https://"$STORAGE_NAME".blob.core.windows.net/opsmanager/opsman-"$OPSMAN_VERSION".vhd \
  --location $LOCATION \
  --os-type Linux

  az vm create --name opsman-"$OPSMAN_VERSION" --resource-group "$RESOURCE_GROUP" \
  --location $LOCATION \
  --nics opsman-nic \
  --image opsman-"$OPSMAN_VERSION" \
  --os-disk-size-gb 128 \
  --os-disk-name opsman-"$OPSMAN_VERSION"-osdisk \
  --admin-username ubuntu \
  --size Standard_DS2_v2 \
  --storage-sku Standard_LRS \
  --ssh-key-value ~/.ssh/azurekeys/opsman.pub

  OPSMAN_IP=$(az network public-ip show --name ops-manager-ip --resource-group "$RESOURCE_GROUP" -o json | jq -r .ipAddress)
  OPSMAN_URL="opsman.$RESOURCE_GROUP.taslab4tanzu.com"
  echo "$MAC_ADMIN" | sudo -S sh -c -e "echo '$OPSMAN_IP' '$OPSMAN_URL' >> /etc/hosts"
}

function configure_opsman_auth_and_uaa(){
  curl -k -X POST -H "Content-Type: application/json" -d "$(opsman_authentication_setup)" "https://$OPSMAN_URL/api/v0/setup"

  echo "Setting up Opsman authentication..."
  sleep 60

  uaac target https://"$OPSMAN_URL"/uaa --skip-ssl-validation
  uaac token owner get opsman admin -s "" -p "$SP_SECRET"
  OPSMAN_TOKEN=$(uaac context | grep access_token | cut -c 21-)
}
