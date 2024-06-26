@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the name prefix of all resources.')
@minLength(5)
@maxLength(20)
param namePrefix string

@description('Specifies the database name to use.')
param database string = ''

@description('Specifies the PostgreSQL login name.')
@secure()
param postgresLogin string

@description('Specifies the PostgreSQL login password.')
@secure()
param postgresLoginPassword string

@description('Specifies the PostgreSQL version.')
@allowed([
  '12'
  '13'
  '14'
  '15'
  '16'
])
param postgresVersion string = '15'

@description('Specifies the Azure AD PostgreSQL administrator user principal name.')
param aadPostgresAdmin string

@description('Specifies the Azure AD PostgreSQL administrator user\'s object ID.')
param aadPostgresAdminObjectID string

@description('Specifies the client IP address to whitelist in the database server\'s firewall.')
param clientIP string = ''

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    namePrefix: namePrefix
    deployDnsZone: (clientIP == '')
  }
}

module postgres 'modules/database.bicep' = {
  name: 'postgres'
  params: {
    location: location
    database: database
    postgresLogin: postgresLogin
    postgresLoginPassword:postgresLoginPassword
    aadPostgresAdmin: aadPostgresAdmin
    aadPostgresAdminObjectID: aadPostgresAdminObjectID
    clientIP: clientIP
    postgresSubnetId: network.outputs.databaseSubnetId
    privateDnsZoneId: network.outputs.privateDnsZoneId
    deployDatabase: false
    version: postgresVersion
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    location: location
    namePrefix: namePrefix  
    infrastructureSubnetId: network.outputs.infraSubnetId
  }
}

output environmentId string = environment.outputs.environmentId
output identityUPN string = environment.outputs.identityUPN
output postgresHost string = postgres.outputs.serverFqdn
