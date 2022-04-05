@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(12)
param name string = 'containerapp'

@description('Specifies the Container App\'s image.')
param image string = 'joergjo/go-helloworld:latest'

@description('Specifies the environment variables used by the application.')
param envVars array = [
  {
    name: 'HELLOWORLD_ENABLE_ABOUT'
    value: 'false'
  }
]

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: '${name}-vnet'
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    location: location
    namePrefix: name
    infrastructureSubnetId: network.outputs.infraSubnetId
    runtimeSubnetId: network.outputs.runtimeSubnetId
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: name
    location: location
    environmentId: environment.outputs.environmentId
    image: image
    envVars: envVars
  }
}

output fqdn string = app.outputs.fqdn
