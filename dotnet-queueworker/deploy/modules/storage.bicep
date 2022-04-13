@description('Specifies the name of the Azure Storage account.')
param storageAccountName string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of the request queue.')
param queueName string

@description('Specifies the subnet resource ID for the Container App environment.')
param infrastructureSubnetId string

@description('Specifies the subnet resource ID for the Container App pods.')
param runtimeSubnetId string

@description('Specifies public IP address used by the executing client.')
@secure()
param clientPublicIpAddress string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
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
        {
          id: runtimeSubnetId
          action: 'Allow'
        }
      ]
      ipRules: [
        {
          action: 'Allow'
          value: clientPublicIpAddress
        }
      ]
    }
  }
}

resource workerQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-08-01' = {
  name: '${storageAccount.name}/default/${queueName}'
}
