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

resource_group=$CONTAINERAPP_RESOURCE_GROUP
app=${CONTAINERAPP_NAME:-"todoapi"}
location=${CONTAINERAPP_LOCATION:-"westeurope"}
image=${CONTAINERAPP_IMAGE:-"joergjo/java-boot-todo:stable"}
postgres_login=$CONTAINERAPP_POSTGRES_LOGIN
postgres_login_pwd=$CONTAINERAPP_POSTGRES_LOGIN_PWD
database=${CONTAINERAPP_POSTGRES_DB-"demo"}
timestamp=$(date +%s)
client_ip=$(curl -s 'https://api.ipify.org?format=text')

az group create \
  --resource-group "$resource_group" \
  --location "$location"

identity_upn=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --template-file main-infra.bicep \
  --parameters namePrefix="$app" postgresLogin="$postgres_login" \
    postgresLoginPassword="$postgres_login_pwd" database="$database" \
    clientIP="$client_ip" \
  --query properties.outputs.identityUPN.value \
  --output tsv)

db_server=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "env-$timestamp" \
  --query properties.outputs.postgresServer.value \
  --output tsv)

current_user=$(az ad signed-in-user show --query userPrincipalName --output tsv)
echo "Please set $current_user as Azure AD database administrator in the Azure portal. Press <Enter> when ready to continue."
read

token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)
export PGPASSWORD=$token

cat << EOF > prepare-db.generated.sql
SELECT * FROM pgaadauth_create_principal('${identity_upn}', false, false);
CREATE DATABASE "${database}";
GRANT ALL PRIVILEGES ON DATABASE "${database}" TO "${identity_upn}";
EOF

psql "host=${db_server}.postgres.database.azure.com user=${current_user} dbname=postgres sslmode=require" -f prepare-db.generated.sql

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
    identityUPN="$identity_upn" postgresServer="$db_server" database="$database"  \
  --query properties.outputs.fqdn.value \
  --output tsv)

echo "Application has been deployed successfully. You can access it at https://$fqdn"
