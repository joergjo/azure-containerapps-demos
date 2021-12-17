#!/bin/bash

# Before running this script, create a file "azuredeploy.parameters.json" in the same directory as azuredeploy.josn and deploy.sh and set these values
# - location (optional)
# - environmentName
# - postgresHost
# - postgresUsername
# - postgresPassword

name=sb-todo-api
resource_group_name=containerapps

az deployment group create \
    --resource-group $resource_group_name \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json

fqdn=$(az containerapp show \
  --name $name \
  --resource-group $resource_group_name \
  --query configuration.ingress.fqdn -o tsv)

echo "Application endpoint available at $fqdn"
