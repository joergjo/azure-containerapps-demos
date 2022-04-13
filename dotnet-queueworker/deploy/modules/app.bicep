@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container image.')
param image string

@description('Specifies the Storage Account name used for messaging.')
param storageAccountName string

@description('Specifies the Application Insights connection string.')
param appInsightsConnectionString string

@description('Specifies the storage queue\'s name.')
param queueName string

@description('Specifies whether queue messages are to be Base64 decoded.')
param decodeBase64 bool

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource containerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        enabled: false
      }
      secrets: [
        {
          name: 'queue-connection'
          value: storageAccountConnectionString
        }
        {
          name: 'appinsights-connection'
          value: appInsightsConnectionString
        }
      ]  
    }
    template: {
      containers: [
        {
          image: image
          name: name
          env: [
            {
              name: 'ApplicationInsights__ConnectionString'
              secretRef: 'appinsights-connection'
            }
            {
              name: 'WorkerOptions__StorageConnectionString'
              secretRef: 'queue-connection'
            }
            {
              name: 'WorkerOptions__QueueName'
              value: queueName
            }
            {
              name: 'WorkerOptions__DecodeBase64'
              value: '${decodeBase64}'
            }
            {
              name: 'Logging__Console__DisableColors'
              value: 'true'
            }

          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'queuescale'
            azureQueue: {
              queueName: queueName
              queueLength: 100
              auth: [
                {
                  secretRef: 'queue-connection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}
