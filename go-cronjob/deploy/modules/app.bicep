@description('Specifies the name of the Container App.')
param name string

@description('Specifies the location to deploy to.')
param location string 

@description('Specifies the name of Azure Container Apps environment to deploy to.')
param environmentId string

@description('Specifies the container image.')
param image string

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      dapr: {
        enabled: true
        appId: 'go-cronjob'
      }
    }
    template: {
      containers: [
        {
          image: image
          name: name
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
          rules: [
            {
              name: 'cronrule'
              custom: {
                type: 'cron'
                metadata: {
                  timezone: 'Europe/Berlin'  
                  start: '30 * * * *'
                  end: '45 * * * *'         
                  desiredReplicas: '1'
                }
            }
          }
        ]
      }
    }
  }
}
