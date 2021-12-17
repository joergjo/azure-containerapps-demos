#!/bin/bash
name=helloworld
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

curl -i https://$fqdn/sayHelloWorld

az deployment group create \
    --resource-group $resource_group_name \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json showVersion=true
  