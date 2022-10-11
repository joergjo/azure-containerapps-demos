@description('Specifies the name of the Azure Database for PostgreSQL flexible server.')
param serverName string

@description('Specifies the name of PostgreSQL database used by the application.')
param databaseName string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the PostgreSQL version.')
@allowed([
  '12'
  '13'
  '14'
])
param version string = '13'

@description('Specifies the PostgreSQL administrator login name.')
@secure()
param administratorLogin string

@description('Specifies the PostgreSQL administrator login password.')
@secure()
param administratorLoginPassword string

@description('Specifies the subnet resource ID of the delegated subnet for Azure Database.')
param postgresSubnetId string

@description('Specifies the resource ID of the private DNS zone name.')
param privateDnsZoneId string

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
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
    network: {
      delegatedSubnetResourceId: postgresSubnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
    }
    version: version
    createMode: 'Default'
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2021-06-01' = {
  name: databaseName
  parent: postgres
}
