#!/usr/bin/env bash

stage_product()
{
  cat <<EOF
{"name": "cf",
"product_version": "$TAS_VERSION"}
EOF
}

generate_pivnet_token()
{
cat <<EOF
{"refresh_token":"$REFRESH_TOKEN"}
EOF
}


associate_stemcell()
{
  cat <<EOF
{
  "products": [
    {
      "guid": "$CF_GUID",
      "staged_stemcells": [
        {
          "os": "ubuntu-xenial",
          "version": "$STEMCELL_VERSION"
        }
      ]
    }
  ]
}
EOF
}

function download_tas(){
  echo "Retrieving Tanzu Network access token..."

  PIVNET_TOKEN=$(curl -sX POST https://network.pivotal.io/api/v2/authentication/access_tokens -d "$(generate_pivnet_token)" | jq -r '.access_token')

  echo "Creating a product download link..."
  RELEASE_ID=$(curl -sX GET https://network.pivotal.io/api/v2/products/elastic-runtime/releases -H "Authorization: Bearer $PIVNET_TOKEN" |jq -r --arg TAS_VERSION "$TAS_VERSION" '.[] | .[] | select(.version==$TAS_VERSION) | .id')

  PRODUCT_FILE_URL=$(curl -sX GET "https://network.pivotal.io/api/v2/products/elastic-runtime/releases/$RELEASE_ID/product_files" -H "Authorization: Bearer $PIVNET_TOKEN" | jq -r '.[] | .[] | select(.name=="Pivotal Application Service") | ._links.download.href')

  echo "Downloading TAS..."
  DOWNLOAD_LINK=$(curl -sX GET $PRODUCT_FILE_URL -H "Authorization: Bearer $PIVNET_TOKEN" | awk '{ print substr ($0, 36, length($0) - 66 ) }' | sed 's/amp;//g')

  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL "cat << EOF > /home/ubuntu/download_tas.sh
  curl -X GET '$DOWNLOAD_LINK' -o tas-tile.pivotal
  EOF"
}

function upload_and_stage_tas(){
  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL 'bash /home/ubuntu/download_tas.sh'

  echo "Uploading TAS to Opsman...this could take up to an hour..."
  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL "curl -k "https://$OPSMAN_IP/api/v0/available_products" -X POST -H 'Authorization: Bearer $OPSMAN_TOKEN' -F 'product[file]=@/home/ubuntu/tas-tile.pivotal'"

  echo "TAS upload completed..."

  echo "Staging TAS..."
  curl -k -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(stage_product)" "https://$OPSMAN_URL/api/v0/staged/products"

  echo "Downloading Stemcell..."
  STEMCELL_ID=$(curl -sX GET "https://network.pivotal.io/api/v2/products/elastic-runtime/releases/$RELEASE_ID/dependencies" -H "Authorization: Bearer $PIVNET_TOKEN" | jq -r '.[] | .[] | .[] | select(.product.slug=="stemcells-ubuntu-xenial") | .id' 2>/dev/null | sed 1q)

  STEMCELL_VERSION=$(curl -sX GET "https://network.pivotal.io/api/v2/products/elastic-runtime/releases/$RELEASE_ID/dependencies" -H "Authorization: Bearer $PIVNET_TOKEN" | jq -r '.[] | .[] | .[] | select(.product.slug=="stemcells-ubuntu-xenial") | .version' 2>/dev/null | sed 1q)

  STEMCELL_PRODUCT_URL=$(curl -sX GET "https://network.pivotal.io/api/v2/products/stemcells-ubuntu-xenial/releases/$STEMCELL_ID/product_files" -H "Authorization: Bearer $PIVNET_TOKEN" | jq -r '.[] | .[] | select(.name | contains("Azure") ) | ._links.download.href' 2>/dev/null)

  STEMCELL_DOWNLOAD_LINK=$(curl -sX GET $STEMCELL_PRODUCT_URL -H "Authorization: Bearer $PIVNET_TOKEN" | awk '{ print substr ($0, 36, length($0) - 66 ) }' | sed 's/amp;//g')

  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL "cat << EOF > /home/ubuntu/download_stemcell.sh
  curl -O -J -X GET '$STEMCELL_DOWNLOAD_LINK'
  EOF"

  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL 'bash /home/ubuntu/download_stemcell.sh'

  echo "Uploading Stemcell to Opsman..."

  ssh -q -o StrictHostKeyChecking=no -i ~/.ssh/azurekeys/opsman ubuntu@$OPSMAN_URL "curl -k "https://$OPSMAN_IP/api/v0/stemcells" -X POST -H 'Authorization: Bearer $OPSMAN_TOKEN' -F 'stemcell[file]=@/home/ubuntu/bosh-stemcell-$STEMCELL_VERSION-azure-hyperv-ubuntu-xenial-go_agent.tgz' -F 'stemcell[floating]=false'"

  echo "Stemcell upload completed..."

  CF_GUID=$(curl -k -X GET https://$OPSMAN_URL/api/v0/staged/products -H "Authorization: Bearer $OPSMAN_TOKEN" | jq -r '.[] | select(.type=="cf") | .guid')


  curl -k -X PATCH -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(associate_stemcell)" "https://$OPSMAN_URL/api/v0/stemcell_associations"

  echo "Stemcell associated with TAS..."
}


apply_changes_json()
{
   cat <<EOF
 {"deploy_products": "all", "ignore_warnings": true}
EOF
}

function apply_changes(){
  curl -k -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(apply_changes_json)" "https://$OPSMAN_URL/api/v0/installations"
}
