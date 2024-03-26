@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string

var identityName = '${namePrefix}-mi'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: identityName
  location: location
}

output name string = managedIdentity.name
output clientId string = managedIdentity.properties.clientId
