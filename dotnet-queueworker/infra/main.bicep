targetScope = 'subscription'

@minLength(6)
@maxLength(24)
@description('Name of the environment.')
param environmentName string

@minLength(6)
@description('Specifies the location to deploy to.')
param location string

@description('Specifies the Container App\'s name.')
param appName string = ''

@description('Specifies the Container App\'s image.')
param image string = ''

@description('Specifies the storage queue\'s name.')
param queueName string = ''

@description('Specifies the name prefix for Azure resources.')
param namePrefix string = ''

@description('Specifies whether storage queue messages are to be Base64 decoded.')
param decodeBase64 bool = true

@description('Specifies public IP address used by the executing client.')
@secure()
param clientPublicIpAddress string = ''

@description('Specifies the Honeycomb API key.')
@secure()
param honeycombApiKey string = ''

@description('Specifies the Honeycomb dataset for metrics.')
param honeycombDataset string = ''

@description('Specifies the Honeycomb endpoint. Uses the US instance by default.')
param honeycombEndpoint string = 'api.honeycomb.io:443'


// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var defaultAppName = 'queueworker'
var defaultImage = 'joergjo/dotnet-queueworker:8.0'
var defaultNamePrefix = 'aca'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
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
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    tags: tags
    namePrefix: !empty(namePrefix) ? namePrefix : defaultNamePrefix
    queueName: !empty(queueName) ? queueName : defaultAppName    
    infrastructureSubnetId: network.outputs.infraSubnetId
    clientPublicIpAddress: clientPublicIpAddress
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
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    honeycombApiKey: honeycombApiKey
    honeycombDataset: honeycombDataset
    honeycombEndpoint: honeycombEndpoint
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  scope: rg
  params: {
    location: location
    tags: tags
    environmentId: environment.outputs.id
    name:  !empty(appName) ? appName : defaultAppName
    image: !empty(image) ? image : defaultImage
    decodeBase64: decodeBase64
    storageAccountName: storage.outputs.storageAccountName
    queueName: storage.outputs.queueName
    containerRegistryName: registry.outputs.name
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_ENVIRONMENT_NAME string = environment.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.appInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.appInsightsName
