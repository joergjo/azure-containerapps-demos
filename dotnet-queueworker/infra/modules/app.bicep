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

@description('Specifies the Azure Container registry name to pull from.')
param containerRegistryName string

@description('Specifies the tags for all resources.')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-mi'
  location: location
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

var acrPullRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry 
  name: guid(subscription().id, resourceGroup().id, appIdentity.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalType: 'ServicePrincipal'
    principalId: appIdentity.properties.principalId
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'queueworker' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
    }
  }
  dependsOn: [
    acrPullAssignment
  ]
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        enabled: false
      }
      ingress: null
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: appIdentity.id
        }
      ]
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
    workloadProfileName: 'Consumption'
  }
}
