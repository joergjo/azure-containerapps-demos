@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container image.')
param image string

@description('Specifies the environment variables used by the application.')
param envVars array

@description('Specifies the name of the User-Assigned Managed Identity for the Container App.')
param identityName string

var port = 8000

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource containerApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: port
      }
      dapr: {
        enabled: false
      }
    }
    template: {
      containers: [
        {
          image: image
          name: name
          env: envVars
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          probes: [
            {
              type: 'liveness'
              httpGet: {
                path: '/'
                port: port
              }
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/'
                port: port
              }
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
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
