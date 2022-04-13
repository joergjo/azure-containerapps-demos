@description('Specifies the name of the virtual network.')
param vnetName string

@description('Specifies the location to deploy to.')
param location string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.150.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'infrastructure'
        properties: {
          addressPrefix: '10.150.0.0/21'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
        }
      }
      {
        name: 'runtime'
        properties: {
          addressPrefix: '10.150.8.0/21'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output infraSubnetId string = vnet.properties.subnets[0].id
output runtimeSubnetId string = vnet.properties.subnets[1].id
