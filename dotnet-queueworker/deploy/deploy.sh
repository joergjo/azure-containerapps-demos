#!/bin/bash

if [[ -z "${CA_RESOURCE_GROUP}" ]]; then
  echo "Please set the CA_RESOURCE_GROUP environment variable to the name of the resource group where the container application will be deployed"
  exit 1
fi

if [[ ! -f "azuredeploy.parameters.json" ]]; then
  echo "Please create a file named 'azuredeploy.parameters.json' in the same directory as 'azuredeploy.json' and set the parameter values."
  echo
  echo "azuredeploy.parameters.json:"
  cat <<EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "<name of your Container Apps environment>"
    },
    "storageConnectionString": {
      "value": "<Storage account connection string>"
    },
    "appInsightsConnectionString": {
      "value": "<Application Insights connection string>"
    },
    "queueName": {
      "value": "<name of your Azure storage queue>"
    }
  }
}
EOF

  exit 1
fi

echo "Deploying container application..."

az deployment group create \
  --resource-group $CA_RESOURCE_GROUP \
  --template-file ./azuredeploy.json \
  --parameters @./azuredeploy.parameters.json

echo "Application is running!"
