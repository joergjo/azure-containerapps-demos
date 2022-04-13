@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(12)
param appName string

@description('Specifies the Container App\'s image.')
param image string = 'joergjo/java-boot-todo:latest'

@description('Specifies the PostgreSQL login name.')
@secure()
param postgresLogin string

@description('Specifies the PostgreSQL login password.')
@secure()
param postgresLoginPassword string

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: '${appName}-vnet'
    privateDnsZoneName: '${appName}.postgres.database.azure.com'
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

var postgresHostName = 'server${uniqueString(resourceGroup().id)}'

module postgres 'modules/database.bicep' = {
  name: 'postgres'
  params: {
    location: location
    serverName: postgresHostName
    databaseName: 'demo'
    postgresSubnetId: network.outputs.databaseSubnetId
    privateDnsZoneId: network.outputs.privateDnsZoneId
    administratorLogin: postgresLogin
    administratorLoginPassword: postgresLoginPassword
  }
}

var secrets = {
  postgres: {
    host: '${postgresHostName}.postgres.database.azure.com'
    user: postgresLogin
    password: postgresLoginPassword
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: appName
    location: location
    environmentId: environment.outputs.environmentId
    image: image
    secrets: secrets
  }
}

output fqdn string = app.outputs.fqdn
