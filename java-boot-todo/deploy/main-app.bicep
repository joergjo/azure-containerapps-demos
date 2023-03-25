@description('Specifies the location to deploy to.')
param location string = resourceGroup().location

@description('Specifies the Container App\'s name.')
@minLength(5)
@maxLength(20)
param appName string

@description('Specifies the Container App\'s image.')
param image string

@description('Specifies the container app\'s user assigned managed identity\'s UPN.')
param identityUPN string

@description('Specifies the Containe App environment\'s resource id.')
param environmentId string

@description('Specifies the Azure Database for PostgreSQL server\'s FQDN.')
param postgresHost string

@description('Specifies the database name to use.')
param database string

@description('Specifies the Datadog API key.')
@secure()
param datadogApiKey string




module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    name: appName
    location: location
    environmentId: environmentId
    image: image
    identityUPN: identityUPN
    database: database
    postgresHost: postgresHost
    datadogApiKey: datadogApiKey

  }
}

output fqdn string = app.outputs.fqdn
