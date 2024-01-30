@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the subnet resource ID for the Container App environment.')
param infrastructureSubnetId string

@description('Specifies the Log Analytics workspace to connect to.')
param workspaceName string

@description('Specifies the Application Insights connection string.')
param appInsightsConnectionString string

@description('Specifies the tags for all resources.')
param tags object = {}

var uid = uniqueString(resourceGroup().id)
var environmentName = '${namePrefix}${uid}-env'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource environment 'Microsoft.App/managedEnvironments@2023-08-01-preview' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    appInsightsConfiguration:{
      connectionString: appInsightsConnectionString
    }
    openTelemetryConfiguration:{
      tracesConfiguration:{
        destinations:['appInsights']
      }
      logsConfiguration:{
        destinations:['appInsights']
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

output id string = environment.id
output name string = environment.name
