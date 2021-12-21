#!/bin/bash

if [[ -z "${CA_RESOURCE_GROUP}" ]]; then
  echo "Please set the CA_RESOURCE_GROUP environment variable to the name of the resource group where the container application will be deployed"
  exit 1
fi

if [[ ! -f "agent/azuredeploy.parameters.json" ]]; then
echo "Please create a file named 'azuredeploy.parameters.json' in 'agent' subdirectory."
echo
echo "agent/azuredeploy.parameters.json:"
cat << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "<name of your Container Apps environment>"
    },
    "ddApiKey": {
      "value": "<Datadog API key>"
    }
  }
}
EOF

exit 1
fi

if [[ ! -f "app/azuredeploy.parameters.json" ]]; then
echo "Please create a file named 'azuredeploy.parameters.json' in 'app' subdirectory."
echo
echo "app/azuredeploy.parameters.json:"
cat << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "<name of your Container Apps environment>"
    },
    "postgresHost": {
      "value": "<FQDN of your PostgreSQL server>"
    },
    "postgresUser": {
      "value": "<PostgreSQL user name>"
    },
    "postgresPassword": {
      "value": "<PostgreSQL password>"
    }
  }
}
EOF

exit 1
fi

echo "Deploying container application with shared Datadog agent..."

az deployment group create \
    --resource-group $CA_RESOURCE_GROUP \
    --template-file agent/azuredeploy.json \
    --parameters @agent/azuredeploy.parameters.json

dd_agent_fqdn=$(az containerapp show \
  --name dd-agent-shared \
  --resource-group $CA_RESOURCE_GROUP \
  --query configuration.ingress.fqdn \
  --output tsv)

az deployment group create \
    --resource-group $CA_RESOURCE_GROUP \
    --template-file app/azuredeploy.json \
    --parameters @app/azuredeploy.parameters.json \
    --parameters ddAgentHost=${dd_agent_fqdn}

api_fqdn=$(az containerapp show \
  --name sb-todo-api \
  --resource-group $CA_RESOURCE_GROUP \
  --query configuration.ingress.fqdn \
  --output tsv)

echo "Application endpoint available at ${api_fqdn}"
