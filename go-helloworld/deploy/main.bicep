@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(12)
param appName string

@description('Specifies the Container App\'s image.')
param image string

@description('Specifies the environment variables used by the application.')
param envVars array = [
  {
    name: 'HELLOWORLD_ENABLE_ABOUT'
    value: 'false'
  }
]

module appIdentity 'modules/identity.bicep' = {
  name: 'appIdentity'
  params: {
    namePrefix: appName
    location: location
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    namePrefix: appName
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    location: location
    namePrefix: appName
    infrastructureSubnetId: network.outputs.infraSubnetId
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: appName
    location: location
    environmentId: environment.outputs.environmentId
    image: image != '' ? image : 'joergjo/go-helloworld:latest'
    envVars: envVars
    identityName: appIdentity.outputs.name
  }
}

output fqdn string = app.outputs.fqdn
