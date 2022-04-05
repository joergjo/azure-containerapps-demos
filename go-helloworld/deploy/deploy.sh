#!/bin/bash
if [ -z "$CONTAINERAPP_RESOURCE_GROUP_NAME" ]; then
    echo "CONTOSOADS_RESOURCE_GROUP_NAME is not set. Please set it to the name of the resource group to deploy to."
    exit 1
fi

resource_group_name=$CONTAINERAPP_RESOURCE_GROUP_NAME
app_name=${CONTAINERAPP_BASE_NAME:-containerapp}
location=${CONTAINERAPP_LOCATION:-westeurope}
tag=${CONTAINERAPP_WEBAPP_TAG:-latest}
show_version=${CONTAINERAPP_SHOW_VERSION:-true}
deployment_name="$app_name-$(date +%s)"

az group create \
  --resource-group "$resource_group_name" \
  --location "$location"

fqdn=$(az deployment group create \
  --resource-group "$resource_group_name" \
  --name "$deployment_name" \
  --template-file main.bicep \
  --query properties.outputs.fqdn.value \
  --output tsv)

echo "Application has been deployed successfully. You can access it at https://$fqdn"
