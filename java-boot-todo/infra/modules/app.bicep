@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container image.')
param image string

@description('Specifies the application\'s secrets.')
param secrets array

@description('Specifies the application\'s environment.')
param envVars array

@description('Specifies the container app\'s user assigned managed identity\'s UPN.')
param identityUpn string

@description('Specifies the Azure Container registry name to pull from.')
param containerRegistryName string

@description('Specifies the tags for all resources.')
param tags object = {}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityUpn
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
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

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'todoapi' })
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
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: appIdentity.id
        }
      ]
      secrets: secrets
    }
    template: {
      containers: [
        {
          image: image
          name: name
          env: envVars
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          probes: [
            {
              type: 'startup'
              httpGet: {
                scheme: 'HTTP'
                path: '/actuator/health/liveness'
                port: 4004
              }
              failureThreshold: 10
              periodSeconds: 15
            }
            {
              type: 'liveness'
              httpGet: {
                scheme: 'HTTP'
                path: '/actuator/health/liveness'
                port: 4004
              }
            }
            {
              type: 'readiness'
              httpGet: {
                scheme: 'HTTP'
                path: '/actuator/health/readiness'
                port: 4004
              }
              initialDelaySeconds: 15
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'httpscale'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
    workloadProfileName: 'Consumption'
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
output name string = containerApp.name
