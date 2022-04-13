@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(12)
param appName string

@description('Specifies the Container App\'s image.')
param image string = 'joergjo/dotnet-queueworker:latest'

@description('Specifies the storage queue\'s name.')
param queueName string

@description('Specifies whether storage queue messages are to be Base64 decoded.')
param decodeBase64 bool

@description('Specifies public IP address used by the executing client.')
@secure()
param clientPublicIpAddress string

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: '${appName}-vnet'
  }
}

var storageAccountName = '${appName}${uniqueString(resourceGroup().id)}'

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    queueName: queueName
    infrastructureSubnetId: network.outputs.infraSubnetId
    runtimeSubnetId: network.outputs.runtimeSubnetId
    clientPublicIpAddress: clientPublicIpAddress
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    location: location
    namePrefix: appName
    infrastructureSubnetId: network.outputs.infraSubnetId
    runtimeSubnetId: network.outputs.runtimeSubnetId
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: appName
    location: location
    environmentId: environment.outputs.environmentId
    image: image
    storageAccountName: storageAccountName
    queueName: queueName
    decodeBase64: decodeBase64
    appInsightsConnectionString: environment.outputs.appInsightsConnectionString
  }
}
