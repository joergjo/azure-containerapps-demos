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

image=${CONTAINERAPP_IMAGE:-"joergjo/java-boot-todo:dd-latest"}
if [ -z "$CONTAINERAPP_DD_API_KEY" ]; then
  echo "CONTAINERAPP_DD_API_KEY is not set. Deploying without Datadog support."
  image=${CONTAINERAPP_IMAGE:-"joergjo/java-boot-todo:latest"}
fi

resource_group="$CONTAINERAPP_RESOURCE_GROUP"
app=${CONTAINERAPP_NAME:-"todoapi"}
location=${CONTAINERAPP_LOCATION:-"westeurope"}
postgres_login="$CONTAINERAPP_POSTGRES_LOGIN"
postgres_login_pwd="$CONTAINERAPP_POSTGRES_LOGIN_PWD"
dd_api_key="$CONTAINERAPP_DD_API_KEY"
dd_application_key="$CONTAINERAPP_DD_APPLICATION_KEY"
dd_version="$CONTAINERAPP_DD_VERSION"
database=${CONTAINERAPP_POSTGRES_DB-"demo"}
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

db_server=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --query properties.outputs.postgresServer.value \
  --output tsv)

db_host=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --query properties.outputs.postgresHost.value \
  --output tsv)

az deployment group create \
  --resource-group "$resource_group" \
  --name "aad-admin-$timestamp" \
  --template-file modules/dbadmin.bicep \
  --parameters server="$db_server" \
    aadPostgresAdmin="$current_user_upn" aadPostgresAdminObjectID="$current_user_objectid" \
  --output none

if [ $? -ne 0 ]; then
  echo "Bicep deployment failed. Please check the error message above."
  exit 1
fi

token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)
export PGPASSWORD=$token

cat << EOF > prepare-db.generated.sql
SELECT * FROM pgaadauth_create_principal('${identity_upn}', false, false);
CREATE DATABASE "${database}";
GRANT ALL PRIVILEGES ON DATABASE "${database}" TO "${identity_upn}";
EOF

psql "host=${db_host} user=${current_user_upn} dbname=postgres sslmode=require" \
  -f prepare-db.generated.sql \
  -v "ON_ERROR_STOP=1"

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
    ddApiKey="$dd_api_key" ddApplicationKey="$dd_application_key" \
    ddVersion="$dd_version" \
  --query properties.outputs.fqdn.value \
  --output tsv)

if [ $? -ne 0 ]; then
  echo "Bicep deployment failed. Please check the error message above."
  exit 1
fi

echo "Application has been deployed successfully to $resource_group."
echo "You can access it at https://$fqdn."
