#!/bin/bash
if [ -z "$CONTAINERAPP_RESOURCE_GROUP" ]; then
  echo "CONTAINERAPP_RESOURCE_GROUP is not set. Please set it to the name of the resource group to deploy to."
  exit 1
fi

if [ -z "$CONTAINERAPP_POSTGRES_LOGIN" ]; then
  echo "CONTAINERAPP_POSTGRES_LOGIN is not set. Please set it to a valid login name for the Container App's database server."
  exit 1
fi

if [ -z "$CONTAINERAPP_POSTGRES_LOGIN_PWD" ]; then
  echo "CONTAINERAPP_POSTGRES_LOGIN_PWD is not set. Please set it to a secure password for the Container App's database server."
  exit 1
fi

image=${CONTAINERAPP_IMAGE:-"joergjo/go-chi-todo:latest"}
resource_group="$CONTAINERAPP_RESOURCE_GROUP"
app=${CONTAINERAPP_NAME:-"go-todo-api"}
location=${CONTAINERAPP_LOCATION:-"westeurope"}
postgres_login="$CONTAINERAPP_POSTGRES_LOGIN"
postgres_login_pwd="$CONTAINERAPP_POSTGRES_LOGIN_PWD"
database=${CONTAINERAPP_POSTGRES_DB-"todo"}
timestamp=$(date +%s)
client_ip=$(curl -s 'https://api.ipify.org?format=text')

az group create \
  --resource-group "$resource_group" \
  --location "$location" \
  --output none

current_user_upn=$(az ad signed-in-user show --query userPrincipalName --output tsv)
current_user_objectid=$(az ad signed-in-user show --query id --output tsv)

identity_upn=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --template-file main-infra.bicep \
  --parameters namePrefix="$app" clientIP="$client_ip" database="$database" \
    aadPostgresAdmin="$current_user_upn" aadPostgresAdminObjectID="$current_user_objectid" \
    postgresLogin="$postgres_login" postgresLoginPassword="$postgres_login_pwd" \
  --query properties.outputs.identityUPN.value \
  --output tsv)

if [ $? -ne 0 ]; then
  echo "Bicep deployment failed. Please check the error message above."
  exit 1
fi

db_host=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --query properties.outputs.postgresHost.value \
  --output tsv)

token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)
export PGPASSWORD=$token

cat << EOF > prepare-db.generated.sql
SELECT * FROM pgaadauth_create_principal('${identity_upn}', false, false);
CREATE DATABASE "${database}";
EOF

psql "host=${db_host} user=${current_user_upn} dbname=postgres sslmode=require" \
  -f prepare-db.generated.sql

migrate -path ../migrations -database "pgx://${current_user_upn}:${token}@${db_host}/${database}?sslmode=require" up

psql "host=${db_host} user=${current_user_upn} dbname=${database} sslmode=require" \
  -c "GRANT ALL on \"todo\" TO \"${identity_upn}\"";

env_id=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --query properties.outputs.environmentId.value \
  --output tsv)

fqdn=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "$app-$timestamp" \
  --template-file main-app.bicep \
  --parameters appName="$app" image="$image" environmentId="$env_id" \
    identityUPN="$identity_upn" postgresHost="$db_host" database="$database" \
  --query properties.outputs.fqdn.value \
  --output tsv)

if [ $? -ne 0 ]; then
  echo "Bicep deployment failed. Please check the error message above."
  exit 1
fi

echo "Application has been deployed successfully to $resource_group."
echo "You can access it at https://$fqdn."
