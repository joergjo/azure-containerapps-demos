@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the subnet resource ID for the Container App environment.')
param infrastructureSubnetId string

@description('Specifies the subnet resource ID for the Container App pods.')
param runtimeSubnetId string

var workspaceName = '${namePrefix}-logs'
var environmentName = '${namePrefix}-env'
var appInsightsName = '${namePrefix}-insights'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'other'
  properties: { 
    Application_Type: 'other'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: environmentName
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
      runtimeSubnetId: runtimeSubnetId
    }
  }
}

output environmentId string = environment.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
