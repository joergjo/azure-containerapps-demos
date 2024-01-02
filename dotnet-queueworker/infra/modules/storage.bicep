@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of the request queue.')
param queueName string

@description('Specifies the subnet resource ID for the Container App environment.')
param infrastructureSubnetId string

@description('Specifies the tags for all resources.')
param tags object = {}

@description('Specifies public IP address used by the executing client.')
@secure()
param clientPublicIpAddress string

var storageAccountName = '${length(namePrefix) <=11 ? namePrefix : substring(namePrefix, 0, 11)}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: infrastructureSubnetId
          action: 'Allow'
        }
      ]
      ipRules: !empty(clientPublicIpAddress) ? [
        {
          action: 'Allow'
          value: clientPublicIpAddress
        }
      ] : null  
    }
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource workerQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = {
  name: queueName
  parent: queueService
}

output storageAccountName string = storageAccount.name
output queueName string = workerQueue.name
