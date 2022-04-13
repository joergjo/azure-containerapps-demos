#!/bin/bash
if [ -z "$CONTAINERAPP_RESOURCE_GROUP_NAME" ]; then
    echo "CONTOSOADS_RESOURCE_GROUP_NAME is not set. Please set it to the name of the resource group to deploy to."
    exit 1
fi

resource_group_name=$CONTAINERAPP_RESOURCE_GROUP_NAME
location=${CONTAINERAPP_LOCATION:-westeurope}
app_name=${CONTAINERAPP_BASE_NAME:-queueworker}
queue_name=${CONTAINERAPP_QUEUE_NAME:-demo}
decode_base64=${CONTAINERAPP_DECODE_BASE64:-true}
deployment_name="$app_name-$(date +%s)"

current_ip=$(curl -s "https://api.ipify.org?format=text")

az group create \
  --resource-group "$resource_group_name" \
  --location "$location"

az deployment group create \
  --resource-group "$resource_group_name" \
  --name "$deployment_name" \
  --template-file main.bicep \
  --parameters appName="$app_name" location="$location" queueName="$queue_name" \
    decodeBase64="$decode_base64" clientPublicIpAddress="$current_ip"

echo "Application has been deployed successfully. Please enqueue a message to the queue and check the output."
