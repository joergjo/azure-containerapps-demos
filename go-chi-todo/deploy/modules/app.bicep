@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container image.')
param image string

@description('Specifies the container app\'s user assigned managed identity\'s UPN.')
param identityUPN string

@description('Specifies the Azure Database for PostgreSQL server\'s FQDN.')
param postgresHost string

@description('Specifies the database name to use.')
param database string

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: identityUPN
}

var allSecrets = [
  {
    name: 'postgres-user'
    value: identityUPN
  }
  {
    name: 'azure-client-id'
    value: appIdentity.properties.clientId
  }
]

var secrets = filter(allSecrets, s => !empty(s.value))

var allEnvVars = [
  {
    name: 'PGHOST'
    value: postgresHost
  }
  {
    name: 'PGUSER'
    secretRef: 'postgres-user'
  }
  {
    name: 'PGDATABASE'
    value: database
  }
  {
    name: 'PGSSLMODE'
    value: 'require'
  }
  {
    name: 'AZURE_CLIENT_ID'
    secretRef: 'azure-client-id'
  }
]

var secretNames = map(secrets, s => s.name)
var envVars = filter(allEnvVars, e => (contains(e, 'secretRef') && contains(secretNames, e.secretRef)) || contains(e, 'value'))
var port = 8080

resource containerApp 'Microsoft.App/containerApps@2022-10-01' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
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
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'liveness'
              httpGet: {
                scheme: 'HTTP'
                path: '/healthz'
                port: port
              }
            }
            {
              type: 'readiness'
              httpGet: {
                scheme: 'HTTP'
                path: '/ready'
                port: port
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
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
