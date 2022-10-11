@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(12)
param appName string

// @description('Specifies the Container App\'s image.')
// param image string

@description('Specifies the PostgreSQL login name.')
@secure()
param postgresLogin string

@description('Specifies the PostgreSQL login password.')
@secure()
param postgresLoginPassword string

@description('Specifies the AAD database administrator\'s UPN')
param aadAdminUPN string

@description('Specifies the AAD database administrator\'s object ID')
param aadAdminOID string

@description('Specifies the client IP address to whitelist')
param clientIP string

@description('Database to be created')
param databaseName string
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
  }
}

var serverName = 'server${uniqueString(resourceGroup().id)}'

module postgres 'modules/database-singlesrv.bicep' = {
  name: 'postgres'
  params: {
    location: location
    serverName: serverName
    databaseName: databaseName
    postgresLogin: postgresLogin
    postgresLoginPassword:postgresLoginPassword
    aadAdminOID: aadAdminOID
    aadAdminUPN: aadAdminUPN
    clientIP: clientIP
  }
}

// var secrets = {
//   postgres: {
//     host: '${postgresHostName}.postgres.database.azure.com'
//     user: postgresLogin
//     password: postgresLoginPassword
//   }
// }

// module app 'modules/app.bicep' = {
//   name: 'app'
//   params: {
//     name: appName
//     location: location
//     environmentId: environment.outputs.environmentId
//     image: image
//     secrets: secrets
//   }
// }

output dbServerFQDN string = postgres.outputs.serverFQDN
output dbServerName string = serverName
output environmentId string = environment.outputs.environmentId
output identityName string = environment.outputs.identityName
