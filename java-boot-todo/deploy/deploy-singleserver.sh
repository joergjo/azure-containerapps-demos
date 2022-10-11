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
aad_admin_upn=$CONTAINERAPP_POSTGRES_AAD_ADMIN_USERNAME
aad_admin_oid=$CONTAINERAPP_POSTGRES_AAD_ADMIN_OBJECTID

location=${CONTAINERAPP_LOCATION:-"westeurope"}
database=${CONTAINERAPP_POSTGRES_DB-"demo"}
deployment="pg-single-server-$(date +%s)"
client_ip=$(curl -s 'https://api.ipify.org?format=text')

az group create \
  --resource-group "$resource_group" \
  --location "$location"

fqdn=$(az deployment group create \
  --resource-group "$resource_group" \
  --name "$deployment" \
  --template-file modules/database-singlesrv.bicep \
  --parameters postgresLogin="$postgres_login" postgresLoginPassword="$postgres_login_pwd" \
    clientIP="$client_ip" aadAdminUPN="$aad_admin_upn" aadAdminOID="$aad_admin_oid" \
    dbName="$database" \
  --query properties.outputs.serverFQDN.value \
  --output tsv)

# server=$(az deployment group show \
#   --resource-group "$resource_group" \
#   --name "$deployment" \
#   --query properties.outputs.serverName.value \
#   --output tsv)

# cat << EOF > create-aad-db-user.generated.sql
# SET aad_validate_oids_in_tenant = off;
# CREATE ROLE "$aad_admin_upn" WITH LOGIN IN ROLE azure_ad_user;
# GRANT ALL PRIVILEGES ON DATABASE $database TO "$aad_admin_upn";
# EOF

# token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv)
# export PGPASSWORD=$token
# psql "host=$fqdn user=$aad_admin_upn@$server dbname=postgres sslmode=require" -f create-aad-db-user.generated.sql

echo "Azure Database for PostgreSQL server $fqdn has been deployed successfully."
