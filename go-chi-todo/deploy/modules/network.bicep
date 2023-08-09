@description('Specifies the name prefix of all resources.')
@minLength(5)
@maxLength(20)
param namePrefix string

@description('Specifies the location to deploy to.')
param location string

@description('Specifies the name of the private DNS zone.')
param privateDnsZoneName string = '${namePrefix}.postgres.database.azure.com'


@description('Specifies whether a private DNS zone will be deployed')
param deployDnsZone bool = true

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.150.0.0/22'
      ]
    }
    subnets: [
      {
        name: 'infrastructure'
        properties: {
          addressPrefix: '10.150.0.0/23'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: 'postgres-delegated'
        properties: {
          addressPrefix: '10.150.2.0/24'
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL/flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${namePrefix}-infra-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAnyHTTPSInbound'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyHTTPInbound'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployDnsZone) {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployDnsZone) {
  parent: privateDnsZone
  name: '${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output vnetId string = vnet.id
output infraSubnetId string = vnet.properties.subnets[0].id
output databaseSubnetId string = vnet.properties.subnets[1].id
output privateDnsZoneId string = deployDnsZone ? privateDnsZone.id : ''
