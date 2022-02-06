#!/bin/bash
timestamp=$(date +%s)
base_name=${1:-cademo-${timestamp}}
location=${2:-northeurope}

resource_group_name=$base_name
la_workspace_name=$base_name-logs
containerapps_env_name=$base_name-env
vnet_name=$base_name-vnet
storage_account_name=cademo${timestamp}
queue_name=cademo

az group create \
  --name $resource_group_name \
  --location $location

az network vnet create \
  --resource-group $resource_group_name \
  --name $vnet_name \
  --location $location \
  --address-prefix 10.150.0.0/16 \
  --query id \
  --output tsv

cp_subnet_id=$(az network vnet subnet create \
  --resource-group $resource_group_name \
  --vnet-name $vnet_name \
  --name control-plane \
  --address-prefixes 10.150.0.0/21 \
  --service-endpoints Microsoft.Storage \
  --query id \
  --output tsv)

app_subnet_id=$(az network vnet subnet create \
  --resource-group $resource_group_name \
  --vnet-name $vnet_name \
  --name applications \
  --address-prefixes 10.150.8.0/21 \
  --service-endpoints Microsoft.Storage \
  --query id \
  --output tsv)

la_workspace_id=$(az monitor log-analytics workspace create \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --location $location \
  --query id \
  --output tsv)

la_workspace_client_id=$(az monitor log-analytics workspace show \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --query customerId \
  --output tsv)

la_workspace_client_secret=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --query primarySharedKey \
  --output tsv)

az containerapp env create \
  --resource-group $resource_group_name \
  --name $containerapps_env_name \
  --logs-workspace-id $la_workspace_client_id \
  --logs-workspace-key $la_workspace_client_secret \
  --location $location \
  --app-subnet-resource-id $app_subnet_id \
  --controlplane-subnet-resource-id $cp_subnet_id

az storage account create \
  --resource-group $resource_group_name \
  --name $storage_account_name \
  --location $location \
  --sku Standard_LRS \
  --min-tls-version TLS1_2

az storage account network-rule add \
  --resource-group $resource_group_name \
  --account-name $storage_account_name \
  --subnet $cp_subnet_id

az storage account network-rule add \
  --resource-group $resource_group_name \
  --account-name $storage_account_name \
  --subnet $app_subnet_id

current_ip=$(curl "https://api.ipify.org?format=text")

az storage account network-rule add \
  --resource-group $resource_group_name \
  --account-name $storage_account_name \
  --ip-address $current_ip

sa_connection_string=$(az storage account show-connection-string \
  --resource-group $resource_group_name \
  --name $storage_account_name \
  --query connectionString \
  --out tsv)

az storage queue create \
  --name $queue_name \
  --connection-string $sa_connection_string

az storage account update \
  --resource-group $resource_group_name \
  --name $storage_account_name \
  --default-action Deny

ai_connection_string=$(az monitor app-insights component create \
  --resource-group $resource_group_name \
  --app ${base_name}-insights \
  --location $location \
  --kind other \
  --workspace $la_workspace_id \
  --query connectionString \
  --output tsv)

cat >./azuredeploy.parameters.json <<EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "$containerapps_env_name"
    },
    "storageConnectionString": {
      "value": "$sa_connection_string"
    },
    "appInsightsConnectionString": {
      "value": "$ai_connection_string"
    },
    "queueName": {
      "value": "$queue_name"
    }
  }
}
EOF

echo "Everything is set up. Please execute the following command to deploy the sample application:"
echo "CA_RESOURCE_GROUP=$resource_group_name ./deploy.sh"
