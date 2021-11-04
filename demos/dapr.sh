#!/bin/bash

resource_group_name="containerapps"
location="northeurope"
containerapps_env="containerapps-01"
storage_account_name="cadaprdemo"

az storage account create \
  --name $storage_account_name \
  --resource-group $resource_group_name \
  --location $location \
  --sku Standard_GRS \
  --kind StorageV2

az containerapp create \
  --name nodeapp \
  --resource-group $resource_group_name \
  --environment $containerapps_env \
  --image dapriosamples/hello-k8s-node:latest \
  --target-port 3000 \
  --ingress 'external' \
  --min-replicas 1 \
  --max-replicas 1 \
  --enable-dapr \
  --dapr-app-port 3000 \
  --dapr-app-id nodeapp \
  --dapr-components ./components.yaml

az containerapp create \
  --name pythonapp \
  --resource-group $resource_group_name \
  --environment $containerapps_env \
  --image dapriosamples/hello-k8s-python:latest \
  --min-replicas 1 \
  --max-replicas 1 \
  --enable-dapr \
  --dapr-app-id pythonapp
