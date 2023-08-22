@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the tags for all resources.')
param tags object = {}

var uid = uniqueString(resourceGroup().id)
var workspaceName = '${namePrefix}${uid}-logs'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

output workspaceId string = logAnalytics.id
output workspaceName string = logAnalytics.name
