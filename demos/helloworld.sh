#!/bin/bash

resource_group_name="containerapps"
location="northeurope"
la_workspace_name="containerapps-logs"
containerapps_env="containerapps-01"

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
  --out tsv)
la_workspace_client_secret=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --query primarySharedKey \
  --out tsv)

az containerapp env create \
  --name $containerapps_env \
  --resource-group $resource_group_name \
  --logs-workspace-id $la_workspace_client_id \
  --logs-workspace-key $la_workspace_client_secret \
  --location $location

name=helloworld
az containerapp create \
  --name $name \
  --resource-group $resource_group_name \
  --environment $containerapps_env \
  --image joergjo/go-helloworld:v1 \
  --target-port 5000 \
  --ingress 'external' \
  --environment-variables HELLOWORLD_ADD_VERSION=true

fqdn=$(az containerapp show \
  --name $name \
  --resource-group $resource_group_name \
  --query configuration.ingress.fqdn \
  --output tsv)

curl -i https://$fqdn/sayHelloWorld

az containerapp revision list \
  --name $name \
  --resource-group $resource_group_name \
  --output table

# Insert correct revision
current_rev=helloworld--gz9n1yq
az containerapp update \
  --name $name \
  --resource-group $resource_group_name \
  --image joergjo/go-helloworld:v2 \
  --traffic-weight "$current_rev=80,latest=20"

az containerapp revision list \
  --name $name \
  --resource-group $resource_group_name \
  --output table

for i in {1..50}; do curl -i https://$fqdn/sayHelloWorld && echo; done
