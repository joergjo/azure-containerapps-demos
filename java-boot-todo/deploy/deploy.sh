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

if [ -z "$CONTAINERAPP_POSTGRES_AAD_ADMIN_USERNAME" ]; then
    echo "CONTAINERAPP_POSTGRES_AAD_ADMIN_USERNAME is not set. Please set it to the UPN of an AAD user to become server admin."
    exit 1
fi

if [ -z "$CONTAINERAPP_POSTGRES_AAD_ADMIN_OBJECTID" ]; then
    echo "CONTAINERAPP_POSTGRES_AAD_ADMIN_OBJECTID is not set. Please set it to the object ID of the AAD admin user."
    exit 1
fi

resource_group=$CONTAINERAPP_RESOURCE_GROUP
postgres_login_pwd=$CONTAINERAPP_POSTGRES_LOGIN_PWD
postgres_login=$CONTAINERAPP_POSTGRES_LOGIN

app=${CONTAINERAPP_NAME:-"todoapi"}
location=${CONTAINERAPP_LOCATION:-"westeurope"}
image=${CONTAINERAPP_IMAGE:-"joergjo/java-boot-todo:latest"}
database=${CONTAINERAPP_POSTGRES_DB-"demo"}
aad_admin_upn=$CONTAINERAPP_POSTGRES_AAD_ADMIN_USERNAME
aad_admin_oid=$CONTAINERAPP_POSTGRES_AAD_ADMIN_OBJECTID

deployment="$app-$(date +%s)"
client_ip=$(curl -s 'https://api.ipify.org?format=text')

az group create \
  --resource-group "$resource_group" \
  --location "$location"

identity=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "$deployment" \
  --template-file main.bicep \
  --parameters appName="$app" databaseName="$database" \
    postgresLogin="$postgres_login" postgresLoginPassword="$postgres_login_pwd"  \
    clientIP="$client_ip" aadAdminUPN="$aad_admin_upn" aadAdminOID="$aad_admin_oid" \
  --query properties.outputs.identityName.value \
  --output tsv)

env_id=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "$deployment" \
  --query properties.outputs.environmentId.value \
  --output tsv)

db_fqdn=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "$deployment" \
  --query properties.outputs.dbServerFQDN.value \
  --output tsv)

db_server=$(az deployment group show \
  --resource-group "$resource_group" \
  --name "$deployment" \
  --query properties.outputs.dbServerName.value \
  --output tsv)

identity_client_id=$(az identity show \
  --name "$identity" \
  --resource-group "$resource_group" \
  --query clientId \
  --output tsv)

cat << EOF > create-aad-db-user.generated.sql
SET aad_validate_oids_in_tenant = off;
CREATE ROLE "$identity" WITH LOGIN PASSWORD '$identity_client_id' IN ROLE azure_ad_user;
GRANT ALL PRIVILEGES ON DATABASE $database TO "$identity";
EOF

token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)
export PGPASSWORD=$token
psql "host=$db_fqdn user=$aad_admin_upn@$db_server dbname=postgres sslmode=require" -f create-aad-db-user.generated.sql

# TODO deploy apps...
# echo "Application has been deployed successfully. You can access it at https://$fqdn"
