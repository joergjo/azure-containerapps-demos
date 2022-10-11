@description('Server name for Azure database for PostgreSQL')
@minLength(8)
param serverName string

@description('Database to be created')
@minLength(4)
param databaseName string

@description('Database administrator login name')
@minLength(4)
param postgresLogin string

@description('Database administrator password')
@minLength(8)
@secure()
param postgresLoginPassword string

@description('AAD Database administrator UPN')
param aadAdminUPN string

@description('AAD Database administrator object ID')
param aadAdminOID string

@description('Specifies the client IP address to whitelist')
param clientIP string

@description('Azure database for PostgreSQL compute capacity in vCores (2,4,8,16,32)')
param skuCapacity int = 2

@description('Azure database for PostgreSQL sku name ')
param skuName string = 'GP_Gen5_2'

@description('Azure database for PostgreSQL Sku Size ')
param skuSizeMB int = 51200

@description('Azure database for PostgreSQL pricing tier')
@allowed([
  'Basic'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'GeneralPurpose'

@description('Azure database for PostgreSQL sku family')
param skuFamily string = 'Gen5'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('PostgreSQL Server backup retention days')
param backupRetentionDays int = 7

@description('Geo-Redundant Backup setting')
param geoRedundantBackup string = 'Disabled'

var postgresqlVersion = '11'

var firewallrules = [
  {
    Name: 'allow-all-azure'
    StartIpAddress: '0.0.0.0'
    EndIpAddress: '255.255.255.255'
  }
  {
    Name: 'allow-client'
    StartIpAddress: clientIP
    EndIpAddress: clientIP
  }
]

resource server 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
    size: '${skuSizeMB}'
    family: skuFamily
  }
  properties: {
    createMode: 'Default'
    version: postgresqlVersion
    administratorLogin: postgresLogin
    administratorLoginPassword: postgresLoginPassword
    storageProfile: {
      storageMB: skuSizeMB
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  name: databaseName
  parent: server
}

resource serverAdmin 'Microsoft.DBforPostgreSQL/servers/administrators@2017-12-01' = {
  name: 'activeDirectory'
  parent: server
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadAdminUPN
    sid: aadAdminOID
    tenantId: tenant().tenantId
  }
}

@batchSize(1)
resource firewallRules 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = [for rule in firewallrules: {
  name: '${server.name}/${rule.Name}'
  properties: {
    startIpAddress: rule.StartIpAddress
    endIpAddress: rule.EndIpAddress
  }
}]

output serverFQDN string = server.properties.fullyQualifiedDomainName
output serverName string = serverName
