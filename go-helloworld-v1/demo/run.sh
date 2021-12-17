#!/bin/bash
################################################################################
# create a file "todo.env" in the same directory as todo.sh and set these values

# BASE_NAME=[name prefix for Azure resources]
# LOCATION=[northeurope or any other supported region]
# APP_NAME=[name of the Container App, optional]
################################################################################
export $(grep -v "^#" helloworld.env | xargs)
resource_group_name=$BASE_NAME
la_workspace_name=$BASE_NAME-logs
containerapps_env_name=$BASE_NAME-env
name=${APP_NAME:-helloworld}

az group create \
  --name $resource_group_name \
  --location $location

az monitor log-analytics workspace create \
  --resource-group $resource_group_name \
  --workspace-name $la_workspace_name \
  --location $LOCATION

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
  --name $containerapps_env_name_name \
  --resource-group $resource_group_name \
  --logs-workspace-id $la_workspace_client_id \
  --logs-workspace-key $la_workspace_client_secret \
  --location $LOCATION

az containerapp create \
  --name $name \
  --resource-group $resource_group_name \
  --environment $containerapps_env_name \
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

###############################################################
# IMPORTANT
# Set "current_rev" to your correct revision before updating
###############################################################
current_rev=helloworld--ik7uwix
az containerapp update \
  --name $name \
  --resource-group $resource_group_name \
  --image joergjo/go-helloworld:v2 \
  --traffic-weight "${current_rev}=80,latest=20"

az containerapp revision list \
  --name $name \
  --resource-group $resource_group_name \
  --output table

for i in {1..50}; do curl -i https://$fqdn/sayHelloWorld && echo; done
