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

@description('Specifies the Honeycomb API key.')
@secure()
param honeycombApiKey string

@description('Specifies the Honeycomb endpoint.')
param honeycombEndpoint string

@description('Specifies the Honeycomb dataset for metrics.')
param honeycombDataset string

@description('Specifies the tags for all resources.')
param tags object = {}

var uid = uniqueString(resourceGroup().id)
var environmentName = '${namePrefix}${uid}-env'
var useHoneycomb = !empty(honeycombApiKey)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource environment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
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
    appInsightsConfiguration: {
      connectionString: appInsightsConnectionString
    }
    openTelemetryConfiguration: {
      destinationsConfiguration: {
        otlpConfigurations: useHoneycomb
          ? [
              {
                name: 'otlp-honeycomb'
                endpoint: honeycombEndpoint
                headers: [
                  {
                    key: 'x-honeycomb-team'
                    value: honeycombApiKey
                  }
                ]
              }
              {
                name: 'otlp-metrics-honeycomb'
                endpoint: honeycombEndpoint
                headers: [
                  {
                    key: 'x-honeycomb-team'
                    value: honeycombApiKey
                  }
                  {
                    key: 'x-honeycomb-dataset'
                    value: honeycombDataset
                  }
                ]
              }
            ]
          : null
      }
      tracesConfiguration: {
        destinations: [useHoneycomb ? 'otlp-honeycomb' : 'appInsights']
      }
      logsConfiguration: {
        destinations: [useHoneycomb ? 'otlp-honeycomb' : 'appInsights']
      }
      metricsConfiguration: useHoneycomb
        ? {
            destinations: ['otlp-metrics-honeycomb']
          }
        : null
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
