@description('Specifies the name of the Azure Database for PostgreSQL flexible server.')
param server string

@description('Specifies the Azure AD PostgreSQL administrator user principal name.')
param aadPostgresAdmin string

@description('Specifies the Azure AD PostgreSQL administrator user\'s object ID.')
param aadPostgresAdminObjectID string

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' existing = {
  name: server
}

resource postgresAzureADAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  name: aadPostgresAdminObjectID
  parent: postgresServer
  properties: {
    principalName: aadPostgresAdmin
    principalType: 'User'
    tenantId: subscription().tenantId
  }
}

