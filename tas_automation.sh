#!/usr/bin/env bash
#
#
#
set -euxo pipefail

source libs.sh

if is_sourced; then
    echo "This script is being sourced, just execute me."
    return
fi

azure_login
pave_azure

boot_opsman
create_opsman_vm
configure_opsman_auth_and_uaa

configure_bosh_director
configure_bosh_networks
configure_bosh_azs

download_tas
upload_and_stage_tas
apply_changes

echo "

Apply changes to deploy Bosh is currently running. 
You Opsman URL is $OPSMAN_URL
Your username is admin
Your password is $SP_SECRET
ssh to Opsman vm:
ssh -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL

To DELETE this deployment, simply run:
az ad sp delete --id http://BoshAzure$RESOURCE_GROUP.$DOMAIN
az group delete -n $RESOURCE_GROUP -y
NOTE: 'az group delete' can take a long time

Don't forget to also delete the entry in your local /etc/hosts:
$OPSMAN_IP $OPSMAN_URL
"
