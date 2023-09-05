targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Specifies the Container App\'s name.')
param appName string = ''

@description('Specifies the name prefix for Azure resources.')
param namePrefix string = ''

@description('Specifies the database name to use.')
param database string = 'demo'

@description('Specifies the PostgreSQL login name.')
@secure()
param postgresLogin string = ''

@description('Specifies the PostgreSQL login password.')
@secure()
param postgresLoginPassword string = ''

@description('Specifies the Azure AD PostgreSQL administrator user principal name.')
param aadPostgresAdmin string = ''

@description('Specifies the Azure AD PostgreSQL administrator user\'s object ID.')
param aadPostgresAdminObjectId string = ''

@description('Specifies the Datadog API key.')
@secure()
param ddApiKey string = ''

@description('Specifies the Datadog Application key.')
@secure()
param ddApplicationKey string = ''

@description('Specifies the Datadog site.')
param ddSite string = 'datadoghq.com'

@description('Specifies the Datadog environment tag.')
param ddEnv string = 'dev'

@description('Specifies the Datadog global tags.')
param ddTags string = ''

@description('Specifies public IP address used by the executing client.')
@secure()
param clientPublicIpAddress string = ''

@description('Specifies whether the app has been previously deployed.')
param appExists bool = false

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var defaultAppName = 'todoapi'
var defaultNamePrefix = 'aca'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: environmentName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
  }
}

module registry 'modules/registry.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
  }
}

module postgres 'modules/database.bicep' = {
  name: 'postgres'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
    aadPostgresAdmin: aadPostgresAdmin
    aadPostgresAdminObjectId: aadPostgresAdminObjectId
    clientPublicIpAddress: clientPublicIpAddress
    deployDatabase: false
    database: database
    postgresLogin: postgresLogin
    postgresLoginPassword: postgresLoginPassword
    postgresSubnetId: network.outputs.databaseSubnetId
    privateDnsZoneId: network.outputs.privateDnsZoneId
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
    infrastructureSubnetId: network.outputs.infraSubnetId
    workspaceName: monitoring.outputs.workspaceName
  }
}

module app 'modules/app-upsert.bicep' = {
  name: 'app'
  scope: rg
  params: {
    location: location
    tags: tags
    environmentId: environment.outputs.id
    name:  !empty(appName) ? appName : defaultAppName
    containerRegistryName: registry.outputs.name
    database: database
    ddApiKey: ddApiKey
    ddApplicationKey: ddApplicationKey
    ddEnv: ddEnv
    ddSite: ddSite
    ddTags: ddTags
    identityUpn: environment.outputs.appIdentityUpn
    postgresHost: postgres.outputs.serverFqdn
    exists: appExists
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_ENVIRONMENT_NAME string = environment.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.name
output AZURE_POSTGRESQL_SERVER_FQDN string = postgres.outputs.serverFqdn
output AZURE_POSTGRESQL_SERVER_NAME string = postgres.outputs.serverName
output AZURE_POSTGRESQL_DATABASE_NAME string = postgres.outputs.databaseName
output AZURE_APP_IDENTITY_UPN string = environment.outputs.appIdentityUpn
output SERVICE_TODOAPI_NAME string = app.outputs.name
output SERVICE_API_ENDPOINTS array = [ app.outputs.fqdn ]
