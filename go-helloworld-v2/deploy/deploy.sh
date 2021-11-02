#!/bin/bash
name=helloworld-rev
resource_group_name=containerapps-preview

az deployment group create \
    --resource-group $resource_group_name \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json showVersion=true

fqdn=$(az containerapp show \
  --name $name \
  --resource-group $resource_group_name \
  --query configuration.ingress.fqdn -o tsv)

echo "Application endpoint available at $fqdn"

curl -i https://$fqdn/sayHelloWorld

# az deployment group create \
#     --resource-group $resource_group_name \
#     --template-file azuredeploy.v2.json \
#     --parameters @azuredeploy.parameters.json showVersion=true

az containerapp update \
  --name $name \
  --resource-group $resource_group_name \
  --image joergjo/go-helloworld:v2

# Replace the following value with the actual revision name
previous=<revision>
az containerapp update \
  --name $name \
  --resource-group $resource_group_name \
  --traffic-weight $previous=80,latest=20
