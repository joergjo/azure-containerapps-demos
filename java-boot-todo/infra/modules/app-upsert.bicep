@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container app\'s user assigned managed identity\'s UPN.')
param identityUpn string

@description('Specifies the Azure Database for PostgreSQL server\'s FQDN.')
param postgresHost string

@description('Specifies the database name to use.')
param database string

@description('Specifies the Datadog API key.')
@secure()
param ddApiKey string

@description('Specifies the Datadog Application key.')
@secure()
param ddApplicationKey string

@description('Specifies the Datadog site.')
param ddSite string

@description('Specifies the Datadog environment tag.')
param ddEnv string

@description('Specifies the Datadog global tags.')
param ddTags string

@description('Specifies the Azure Container registry name to pull from.')
param containerRegistryName string

@description('Specifies whether the app has been previously deployed.')
param exists bool

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

var allSecrets = [
  {
    name: 'postgres-user'
    value: identityUpn
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
  // {
  //   name: 'SPRING_PROFILES_ACTIVE'
  //   value: 'json-logging'
  // }
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
    name: 'DD_TAGS'
    value: ddTags
  }
  {
    name: 'DD_AZURE_SUBSCRIPTION_ID'
    value: subscription().subscriptionId
  }
  {
    name: 'DD_AZURE_RESOURCE_GROUP'
    value: resourceGroup().name
  }
]

var secretNames = map(secrets, s => s.name)
var envVars = filter(allEnvVars, e => (contains(e, 'secretRef') && contains(secretNames, e.secretRef)) || contains(e, 'value'))
var image = !empty(ddApiKey) ? 'joergjo/java-boot-todo:dd-sha-f35ff01' : 'joergjo/java-boot-todo:latest'

resource existingContainerApp 'Microsoft.App/containerApps@2023-05-01' existing = if (exists) {
  name: name
}

module containerApp 'app.bicep' = {
  name: '${deployment().name}-update'
  params: {
    name: name
    location: location
    tags: tags
    environmentId: environmentId
    image: exists ? existingContainerApp.properties.template.containers[0].image : image
    secrets: secrets
    envVars: envVars
    containerRegistryName: containerRegistryName
    identityUpn: identityUpn
  }
}

output fqdn string = containerApp.outputs.fqdn
output name string = containerApp.outputs.name
