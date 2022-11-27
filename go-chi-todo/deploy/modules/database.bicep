@description('Specifies the name of the Azure Database for PostgreSQL flexible server.')
param server string

@description('Specifies the name of PostgreSQL database used by the application.')
param database string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the PostgreSQL version.')
@allowed([
  '12'
  '13'
  '14'
])
param version string = '14'

@description('Specifies the PostgreSQL administrator login name.')
@secure()
param postgresLogin string

@description('Specifies the PostgreSQL administrator login password.')
@secure()
param postgresLoginPassword string

@description('Specifies the subnet resource ID of the delegated subnet for Azure Database.')
param postgresSubnetId string

@description('Specifies the resource ID of the private DNS zone name.')
param privateDnsZoneId string

@description('Specifies the client IP address to whitelist in the database server\'s firewall.')
param clientIP string

@description('Specifies whether to create the database specified by \'database\'.')
param deployDatabase bool = true

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

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: server
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresLogin
    administratorLoginPassword: postgresLoginPassword
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

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2021-06-01' = if (deployDatabase) {
  name: database
  parent: postgresServer
}

@batchSize(1)
resource firewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2021-06-01' = [for rule in firewallrules: if (deployAsPublic)  {
  name: '${postgresServer.name}/${rule.name}'
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
