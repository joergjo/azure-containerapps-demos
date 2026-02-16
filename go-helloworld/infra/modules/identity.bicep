@description('Specifies the name prefix of all resources.')
param namePrefix string

@description('Specifies the location to deploy to.')
param location string

var identityName = '${namePrefix}-mi'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
}

output name string = managedIdentity.name
output clientId string = managedIdentity.properties.clientId
