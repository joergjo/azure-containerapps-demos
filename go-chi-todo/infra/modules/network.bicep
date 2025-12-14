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

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
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
            id: infraNsg.id
          }
        }
      }
      {
        name: 'postgres'
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
          networkSecurityGroup: {
            id: postgresNsg.id
          }
        }
      }
    ]
  }
}

resource infraNsg 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
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

resource postgresNsg 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: '${namePrefix}-pgsql-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAzureActiveDirectoryOutbound'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Outbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureActiveDirectory'
          destinationPortRange: '*'
        }
      }

    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployDnsZone) {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployDnsZone) {
  parent: privateDnsZone
  name: '${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output vnetId string = vnet.id
output infraSubnetId string = vnet.properties.subnets[0].id
output databaseSubnetId string = vnet.properties.subnets[1].id
output privateDnsZoneId string = deployDnsZone ? privateDnsZone.id : ''
