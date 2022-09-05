#!/bin/bash
if [ -z "$CONTAINERAPP_RESOURCE_GROUP_NAME" ]; then
    echo "CONTAINERAPP_RESOURCE_GROUP_NAME is not set. Please set it to the name of the resource group to deploy to."
    exit 1
fi

resource_group_name=$CONTAINERAPP_RESOURCE_GROUP_NAME
app_name=${CONTAINERAPP_BASE_NAME:-cronjob}
location=${CONTAINERAPP_LOCATION:-westeurope}
deployment_name="$app_name-$(date +%s)"

az group create \
  --resource-group "$resource_group_name" \
  --location "$location"

fqdn=$(az deployment group create \
  --resource-group "$resource_group_name" \
  --name "$deployment_name" \
  --template-file main.bicep \
  --parameters appName="$app_name" location="$location" \
  --output tsv)

echo "Application has been deployed successfully."
