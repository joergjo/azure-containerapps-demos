#!/bin/bash
name=queueworker
resource_group_name=containerapps

az deployment group create \
    --resource-group $resource_group_name \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json 
  