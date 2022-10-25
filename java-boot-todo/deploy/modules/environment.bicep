@description('Specifies the name prefix of all resources.')
@minLength(5)
@maxLength(12)
param namePrefix string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the subnet resource ID for the Container App environment.')
param infrastructureSubnetId string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${namePrefix}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${namePrefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
    }
  }
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  location: location
  name: '${namePrefix}-mi'
}

output environmentId string = environment.id
output identityUPN string = appIdentity.name
