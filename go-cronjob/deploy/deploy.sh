#!/bin/bash
if [[ -z "$CONTAINERAPP_RESOURCE_GROUP" ]]; then
    echo "CONTAINERAPP_RESOURCE_GROUP is not set. Please set it to the name of the resource group to deploy to."
    exit 1
fi

resource_group=$CONTAINERAPP_RESOURCE_GROUP
app_name=${CONTAINERAPP_NAME:-cronjob}
image=${CONTAINERAPP_IMAGE:-joergjo/go-cronjob:latest}
location=${CONTAINERAPP_LOCATION:-westeurope}
deployment_name="$app_name-$(date +%s)"

az group create \
  --resource-group "$resource_group" \
  --location "$location"

fqdn=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "$deployment_name" \
  --template-file main.bicep \
  --parameters appName="$app_name" image="$image" location="$location" \
  --output tsv)

if [[ -z "$fqdn" ]]; then
    echo "Failed to deploy application."
    exit 1
fi

echo "Application has been deployed successfully."
