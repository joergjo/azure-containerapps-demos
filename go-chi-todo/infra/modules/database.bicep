@description('Specifies the name of the Azure Database for PostgreSQL flexible server.')
param server string = 'server-${uniqueString(resourceGroup().id)}'

@description('Specifies the name of PostgreSQL database used by the application.')
param database string = ''

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the PostgreSQL version.')
@allowed([
  '13'
  '14'
  '15'
  '16'
  '17'
])
param version string = '16'

@description('Specifies the PostgreSQL administrator login name.')
@secure()
param postgresLogin string

@description('Specifies the PostgreSQL administrator login password.')
@secure()
param postgresLoginPassword string

@description('Specifies the Azure AD PostgreSQL administrator user principal name.')
param aadPostgresAdmin string

@description('Specifies the Azure AD PostgreSQL administrator user\'s object ID.')
param aadPostgresAdminObjectID string

@description('Specifies the subnet resource ID of the delegated subnet for Azure Database.')
param postgresSubnetId string

@description('Specifies the resource ID of the private DNS zone name.')
param privateDnsZoneId string

@description('Specifies the client IP address to whitelist in the database server\'s firewall.')
param clientIP string

@description('Specifies whether to create the database specified by \'database\'. This should only be set if Azure AD is not used.')
param deployDatabase bool = (database != '')

var deployAsPublic = (clientIP != '')

var firewallrules = [
  {
    name: 'allow-all-azure'
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  {
    name: 'allow-client'
    startIpAddress: clientIP
    endIpAddress: clientIP
  }
]

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: server
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresLogin
    administratorLoginPassword: postgresLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: deployAsPublic ? null : {
      delegatedSubnetResourceId: postgresSubnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
    }
    version: version
    createMode: 'Default'
  }
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = if (deployDatabase) {
  name: database
  parent: postgresServer
}

resource postgresAzureADAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  name: aadPostgresAdminObjectID
  parent: postgresServer
  properties: {
    principalName: aadPostgresAdmin
    principalType: 'User'
    tenantId: subscription().tenantId
  }
}

@batchSize(1)
resource firewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [for rule in firewallrules: if (deployAsPublic)  {
  name: rule.name
  parent: postgresServer
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
  dependsOn: [
    postgresAzureADAdmin
  ]
}]

output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
