#!/bin/bash

dd_api_key=$1

if [[ -z "$dd_api_key" ]]; then
  echo "Please provide a Datadog API key as the first argument"
  exit 1
fi

base_name=${2:-cademo-$(date +%s)}
location=${3:-northeurope}

resource_group_name=$base_name
la_workspace_name=$base_name-logs
containerapps_env_name=$base_name-env
vnet_name=$base_name-vnet
dns_zone_name=cademos.postgres.database.azure.com

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
  --query id \
  --output tsv)

app_subnet_id=$(az network vnet subnet create \
  --resource-group $resource_group_name \
  --vnet-name $vnet_name \
  --name applications \
  --address-prefixes 10.150.8.0/21 \
  --query id \
  --output tsv)

db_subnet_id=$(az network vnet subnet create \
  --resource-group $resource_group_name \
  --vnet-name $vnet_name \
  --name postgres \
  --address-prefixes 10.150.16.0/24 \
  --query id \
  --output tsv)

az network private-dns zone create \
  --resource-group $resource_group_name \
  --name $dns_zone_name

az network private-dns link vnet create \
  --resource-group $resource_group_name \
  --name $vnet_name-link \
  --zone-name $dns_zone_name \
  --virtual-network $vnet_name \
  --registration-enabled true

az monitor log-analytics workspace create \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --location $location

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
  --name $containerapps_env_name \
  --resource-group $resource_group_name \
  --logs-workspace-id $la_workspace_client_id \
  --logs-workspace-key $la_workspace_client_secret \
  --location $location \
  --app-subnet-resource-id $app_subnet_id \
  --controlplane-subnet-resource-id $cp_subnet_id

pg_admin=capgadmin
pg_pwd=$(uuidgen)
pg_host=$(az postgres flexible-server create \
  --resource-group $resource_group_name \
  --database-name demo \
  --admin-user $pg_admin \
  --admin-password $pg_pwd \
  --version 13 \
  --subnet $db_subnet_id \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --location $location \
  --private-dns-zone $dns_zone_name \
  --query host \
  --output tsv)

cat > ./azuredeploy.parameters.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "$containerapps_env_name"
    },
    "postgresHost": {
      "value": "$pg_host"
    },
    "postgresUser": {
      "value": "$pg_admin"
    },
    "postgresPassword": {
      "value": "$pg_pwd"
    },
    "ddApiKey": {
      "value": "$dd_api_key"
    }
  }
}
EOF

echo "Everything is set up. Please execute the following command to deploy the sample application:"
echo "CA_RESOURCE_GROUP=$resource_group_name ./deploy.sh"
