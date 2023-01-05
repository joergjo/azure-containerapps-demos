@description('Specifies the name of the Azure Database for PostgreSQL flexible server.')
param server string

@description('Specifies the Azure AD PostgreSQL administrator user principal name.')
param aadPostgresAdmin string

@description('Specifies the Azure AD PostgreSQL administrator user\'s object ID.')
param aadPostgresAdminObjectID string

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-03-08-preview' existing = {
  name: server
}

resource postgresAzureADAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-03-08-preview' = {
  name: aadPostgresAdminObjectID
  parent: postgresServer
  properties: {
    principalName: aadPostgresAdmin
    principalType: 'User'
    tenantId: subscription().tenantId
  }
}

