@description('The name of the Azure Data Explorer cluster')
param adxClusterName string

@description('The location of the Azure Data Explorer cluster')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Ft1'
}

@description('The name of the Azure Data Explorer cluster Sku')
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'

@description('The name of the Azure Data Explorer cluster Sku tier')
param skuTier string = 'Basic'

@description('The name of the Azure Data Explorer POS database')
param ft1DBName string = 'fryer'

@description('The name of the Azure Data Explorer Event Hub connection')
param ft1EventHubConnectionName string = 'fryer-eh-messages'

@description('The name of the Azure Data Explorer Event Hub connection')
param ft1EventHubConnectionNamePl string = 'fryer-eh-messagespl'

@description('The name of the Azure Data Explorer Event Hub table')
param tableName string = 'fryer'

@description('The name of the Azure Data Explorer Event Hub table')
param tableNamePl string = 'productionline'

//@description('The name of the Azure Data Explorer Event Hub mapping rule')
//param mappingRuleName string = 'fryer_data_mapping'

//@description('The name of the Azure Data Explorer Event Hub production Line mapping rule')
//param mappingRuleNamePl string = 'productionline_mapping'


@description('The name of the Azure Data Explorer Event Hub data format')
param dataFormat string = 'multijson'

@description('The name of the Azure Data Explorer Event Hub consumer group')
param eventHubConsumerGroupName string = 'cgadx'

@description('The name of the Azure Data Explorer Event Hub consumer group')
param eventHubConsumerGroupNamePl string = 'cgadxpl'


@description('The resource id of the Event Hub')
param eventHubResourceId string

@description('# of nodes')
@minValue(1)
@maxValue(2)
param skuCapacity int = 1


resource adxCluster 'Microsoft.Kusto/clusters@2023-05-02' = {
  name: adxClusterName
  location: location
  tags: resourceTags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
}


resource stagingScript 'Microsoft.Kusto/clusters/databases/scripts@2023-05-02' = {
  name: 'stagingScript'
  parent: ft1fryerDB
  properties: {
    continueOnErrors: false
    forceUpdateTag: 'string'
    scriptContent: loadTextContent('staging.kql')
  }
}
resource fryerScript 'Microsoft.Kusto/clusters/databases/scripts@2023-05-02' = {
  name: 'fryerScript'
  parent: ft1fryerDB
  dependsOn: [
    stagingScript
  ]
  properties: {
    continueOnErrors: false
    forceUpdateTag: 'string'
    scriptContent: loadTextContent('fryer.kql')
  }
}

resource productionLineScript 'Microsoft.Kusto/clusters/databases/scripts@2023-05-02' = {
  name: 'productionLineScript'
  parent: ft1fryerDB
  dependsOn: [
    fryerScript
  ]
  properties: {
    continueOnErrors: false
    forceUpdateTag: 'string'
    scriptContent: loadTextContent('productionline.kql')
  }
}

resource ft1fryerDB 'Microsoft.Kusto/clusters/databases@2023-05-02' = {
  parent: adxCluster
  name: ft1DBName
  location: location
  kind: 'ReadWrite'
}

resource adxEventHubConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2023-08-15' = {
  name: ft1EventHubConnectionName
  kind: 'EventHub'
  dependsOn: [
    fryerScript
  ]
  location: location
  parent: ft1fryerDB
  properties: {
    eventHubResourceId: eventHubResourceId
    consumerGroup: eventHubConsumerGroupName
    tableName: tableName
    dataFormat: dataFormat
    eventSystemProperties: []
    compression: 'None'
    databaseRouting: 'Single'
  }
}

resource adxEventHubConnectionPl 'Microsoft.Kusto/clusters/databases/dataConnections@2023-08-15' = {
  name: ft1EventHubConnectionNamePl
  dependsOn: [
    productionLineScript
  ]
  kind: 'EventHub'
  parent: ft1fryerDB
  location: location
  properties: {
    eventHubResourceId: eventHubResourceId
    consumerGroup: eventHubConsumerGroupNamePl
    tableName: tableNamePl
    dataFormat: dataFormat
    eventSystemProperties: []
    compression: 'None'
    databaseRouting: 'Single'
  }
}
