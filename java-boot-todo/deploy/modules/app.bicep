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

@description('Specifies the Datadog API key.')
@secure()
param ddApiKey string

@description('Specifies the Datadog application key.')
@secure()
param ddApplicationKey string

@description('Specifies the Datadog site.')
param ddSite string

@description('Specifies the Datadog environment tag.')
param ddEnv string

@description('Specifies the Datadog version tag.')
param ddVersion string


resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: identityUPN
}

var allSecrets = [
  {
    name: 'postgres-user'
    value: identityUPN
  }
  {
    name: 'datadog-api-key'
    value: ddApiKey
  }
  {
    name: 'datadog-application-key'
    value: ddApplicationKey
  }
  {
    name: 'azure-client-id'
    value: appIdentity.properties.clientId
  }
]

var secrets = filter(allSecrets, s => !empty(s.value))

var allEnvVars = [
  {
    name: 'POSTGRESQL_FQDN'
    value: postgresHost
  }
  {
    name: 'POSTGRESQL_USERNAME'
    secretRef: 'postgres-user'
  }
  {
    name: 'POSTGRES_DB'
    value: database
  }
  {
    name: 'SPRING_PROFILES_ACTIVE'
    value: 'json-logging'
  }
  {
    name: 'AZURE_CLIENT_ID'
    secretRef: 'azure-client-id'
  }
  {
    name: 'DD_API_KEY'
    secretRef: 'datadog-api-key'
  }
  {
    name: 'DD_APPLICATION_KEY'
    secretRef: 'datadog-application-key'
  }
  {
    name: 'DD_ENV'
    value: ddEnv
  }
  {
    name: 'DD_SITE'
    value: ddSite
  }
  {
    name: 'DD_VERSION'
    value: ddVersion
  }
]

var secretNames = map(secrets, s => s.name)
var envVars = filter(allEnvVars, e => (contains(e, 'secretRef') && contains(secretNames, e.secretRef)) || contains(e, 'value'))

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
        targetPort: 8080
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
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
