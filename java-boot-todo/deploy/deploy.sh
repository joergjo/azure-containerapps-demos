#!/bin/bash
if [ -z "$CONTAINERAPP_RESOURCE_GROUP_NAME" ]; then
    echo "CONTOSOADS_RESOURCE_GROUP_NAME is not set. Please set it to the name of the resource group to deploy to."
    exit 1
fi

if [ -z "$CONTAINERAPP_POSTGRES_LOGIN_PWD" ]; then
    echo "CONTAINERAPP_POSTGRES_LOGIN_PWD is not set. Please set it to a secure password for the Containe App's database server."
    exit 1
fi

resource_group_name=$CONTAINERAPP_RESOURCE_GROUP_NAME
postgres_login_pwd=$CONTAINERAPP_POSTGRES_LOGIN_PWD
postgres_login=${CONTAINERAPP_POSTGRES_LOGIN:-"demoadmin"}
app_name=${CONTAINERAPP_BASE_NAME:-todoapi}
location=${CONTAINERAPP_LOCATION:-westeurope}
deployment_name="$app_name-$(date +%s)"

az group create \
  --resource-group "$resource_group_name" \
  --location "$location"

fqdn=$(az deployment group create \
  --resource-group "$resource_group_name" \
  --name "$deployment_name" \
  --template-file main.bicep \
  --parameters name="$app_name" location="$location" postgresLogin="$postgres_login" postgresLoginPassword="$postgres_login_pwd"  \
  --query properties.outputs.fqdn.value \
  --output tsv)

echo "Application has been deployed successfully. You can access it at https://$fqdn"
