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

az group create \
  --name $resource_group_name \
  --location $location

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
  --location $location

pg_admin=capgadmin
pg_pwd=$(uuidgen)
pg_host=$(az postgres flexible-server create \
  --resource-group $resource_group_name \
  --database-name demo \
  --admin-user $pg_admin \
  --admin-password $pg_pwd \
  --version 13 \
  --public-access 0.0.0.0 \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --location $location \
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
