param releaseName string = 'athena'

@description('ConnectionString to the poseidon database. Put the secretUri if you want to use KeyVault')
@secure()
param databaseConnectionString string

@description('ConnectionString to EventHub/Kafka broker to listen on. Put the secretUri if you want to use KeyVault')
@secure()
param eventSubscribeConnectionString string

@description('EventHub/Kafka topic to listen on')
param eventSubscribeTopic string

@description('ConnectionString to EventHub/Kafka broker to publish on. Put the secretUri if you want to use KeyVault')
@secure()
param eventPublishConnectionString string

@description('EventHub/Kafka topic to publish on')
param eventPublishTopic string

@description('ApplicationInsigth Instrumentation Key. If not provided, the template will create a new AppInsights resource')
@secure()
param appInsightsInstrumentationKey string

@description('URI of the Athena Package available on Internet')
param athenaPackageSource string

var storageName = '${releaseName}sta'
var servicePlanName = '${releaseName}-service-plan'
var functionName = '${releaseName}-function'
var appInsightName = '${releaseName}-appinsights'

resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageName
  tags: {
    displayName: storageName
    releaseName: releaseName
  }
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource servicePlan 'Microsoft.Web/serverfarms@2018-02-01' = {
  name: servicePlanName
  location: resourceGroup().location
  sku: {
    name: 'Y1'
  }
  tags: {
    displayName: servicePlanName
    releaseName: releaseName
  }
}

resource function 'Microsoft.Web/sites@2018-11-01' = {
  name: functionName
  location: resourceGroup().location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    releaseName: releaseName
  }
  properties: {
    serverFarmId: servicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: storage.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage'
          value: storage.properties.primaryEndpoints.blob
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storage.properties.primaryEndpoints.file
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: (empty(appInsightsInstrumentationKey) ? appInsight.properties.InstrumentationKey : appInsightsInstrumentationKey)
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: athenaPackageSource
        }
        {
          name: 'EventPublishConnectionString'
          value: eventPublishConnectionString
        }
        {
          name: 'EventPublishTopic'
          value: eventPublishTopic
        }
        {
          name: 'EventSubscribeConnectionString'
          value: eventSubscribeConnectionString
        }
        {
          name: 'EventSubscribeTopic'
          value: eventSubscribeTopic
        }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: databaseConnectionString
          type: 'SQLServer'
        }
      ]
    }
  }
}

resource appInsight 'Microsoft.Insights/components@2015-05-01' = if (empty(appInsightsInstrumentationKey)) {
  name: appInsightName
  location: resourceGroup().location
  kind: 'web'
  tags: {
    displayName: appInsightName
    releaseName: releaseName
  }
  properties: {
    Application_Type: 'web'
    SamplingPercentage: 100
  }
}

output functionPrincipalId string = function.identity.principalId
output appInsightInstrumentationKey string = empty(appInsightsInstrumentationKey) ? appInsight.properties.InstrumentationKey : appInsightsInstrumentationKey
