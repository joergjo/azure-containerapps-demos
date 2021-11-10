#!/bin/bash
################################################################################
# create a file "todo.env" in the same directory as todo.sh and set these values

# BASE_NAME=[name prefix for Azure resources]
# LOCATION=[northeurope or any other supported region]
# ACR_NAME=[your ACR's name]
# ACR_PASSWORD=[Your ACR's secret]

# POSTGRESQL_HOST=[FQDN of yur PostgreSQL server]
# POSTGRESQL_USERNAME=[PostgreSQL user name]
# POSTGRESQL_PASSWORD=[PostgreSQL password]

# APP_NAME=[name of the Container App, optional]
# TAG=[container image tag, optional]
################################################################################

export $(grep -v "^#" todo.env | xargs)
resource_group_name=$BASE_NAME
la_workspace_name=$BASE_NAME-logs
containerapps_env_name=$BASE_NAME-env
name=${APP_NAME:-todo-api}

az group create \
  --name $resource_group_name \
  --location $LOCATION

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
  --name $containerapps_env_name \
  --resource-group $resource_group_name \
  --logs-workspace-id $la_workspace_client_id \
  --logs-workspace-key $la_workspace_client_secret \
  --location $LOCATION

az containerapp create \
  --name $name \
  --resource-group $resource_group_name \
  --environment $containerapps_env_name \
  --image ${ACR_NAME}.azurecr.io/demos/java-boot-todo:${TAG:-latest} \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username ${ACR_NAME} \
  --registry-password ${ACR_PASSWORD} \
  --secrets "pg-host=${POSTGRESQL_HOST},pg-user=${POSTGRESQL_USERNAME},pg-password=${POSTGRESQL_PASSWORD}" \
  --environment-variables="POSTGRESQL_HOST=secretref:pg-host,POSTGRESQL_USERNAME=secretref:pg-user,POSTGRESQL_PASSWORD=secretref:pg-password,SPRING_PROFILES_ACTIVE=json-logging" \
  --target-port 8080 \
  --ingress "external" \
  --max-replicas 10 \
  --min-replicas 1 \
  --cpu 1.0 \
  --memory 2Gi

fqdn=$(az containerapp show \
  --name $name \
  --resource-group $resource_group_name \
  --query configuration.ingress.fqdn \
  --output tsv)

curl -i https://$fqdn

# Note that even though we didn't specify a scale rule, there is a default HTTP scale rule.
# See https://docs.microsoft.com/en-us/azure/container-apps/scale-app#http
bombardier -c 5 -d 60s -l https://$fqdn
