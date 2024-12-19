// Execute this main file to deploy Prior Authorization related resources in a basic configuration
@minLength(2)
@maxLength(12)
@description('Name for the PriorAuth resource and used to derive the name of dependent resources.')
param priorAuthName string = 'priorAuth'

@description('Set of tags to apply to all resources.')
param tags object = {}

@description('ACR container image url')
@secure()
param acrContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Admin user for the ACR registry of the container image')
@secure()
@minLength(0)
param acrUsername string = ''

@description('Admin password for the ACR registry of the container image')
@secure()
@minLength(0)
param acrPassword string = ''

param streamlitExists bool = false

@description('Admin password for the cluster')
@secure()
param cosmosAdministratorPassword string

@description('API Version of the OpenAI API')
param openAiApiVersion string = '2024-08-01-preview'

@description('List of completion models to be deployed to the OpenAI account.')
param chatCompletionModels array = [
  {
    name: 'gpt-4o'
    version: '2024-08-06'
    skuName: 'GlobalStandard'
    capacity: 25
  }
]

@description('List of embedding models to be deployed to the OpenAI account.')
param embeddingModel object = {
    name: 'text-embedding-ada-002'
    version: '2'
    skuName: 'Standard'
    capacity: 16
}

@description('Embedding model size for the OpenAI Embedding deployment')
param embeddingModelDimension string = '1536'

@description('Storage Blob Container name to land the files for Prior Auth')
param storageBlobContainerName string = 'default'

var name = toLower('${priorAuthName}')
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 7)
var storageServiceName = toLower(replace('storage-${name}-${uniqueSuffix}', '-', ''))
var location = resourceGroup().location

// @TODO: Replace with AVM module
module docIntelligence 'modules/ai/docintelligence.bicep' = {
  name: 'doc-intelligence-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'doc-intelligence-${name}-${uniqueSuffix}'
    location: location
    tags: tags
    aiServiceSkuName: 'S0'
  }
}

// @TODO: Replace with AVM module
module multiAccountAiServices 'modules/ai/mais.bicep' = {
  name: 'multiservice-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'multiservice-${name}-${uniqueSuffix}'
    location: location
    tags: tags
    aiServiceSkuName: 'S0' // or another allowed SKU if appropriate
  }
}

// @TODO: Replace with AVM module
module openAiService 'modules/ai/openai.bicep' = {
  name: 'openai-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'openai-${name}-${uniqueSuffix}'
    location: location
    tags: tags
    aiServiceSkuName: 'S0'
    embeddingModel: embeddingModel
    chatCompletionModels: chatCompletionModels
  }
}

// @TODO: Replace with AVM module
module searchService 'modules/data/search.bicep' = {
  name: 'search-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'search-${name}-${uniqueSuffix}'
    location: location
    tags: tags
    aiServiceSkuName: 'basic'
  }
}

// @TODO: Replace with AVM module
module storageAccount 'modules/data/storage.bicep' = {
  name: 'storage-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: storageServiceName
    location: location
    tags: tags
    aiServiceSkuName: 'Standard_LRS'
  }
}

// @TODO: Replace with AVM module
module appInsights 'modules/monitoring/appinsights.bicep' = {
  name: 'appinsights-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'appinsights-${name}-${uniqueSuffix}'
    location: location
    tags: tags
  }
}

// @TODO: Replace with AVM module
module cosmosDb 'modules/data/cosmos-mongo.bicep' = {
  name: 'cosmosdb-${name}-${uniqueSuffix}-deployment'
  params: {
    aiServiceName: 'cosmosdb-${name}-${uniqueSuffix}'
    location: location
    tags: tags
    cosmosAdministratorPassword: cosmosAdministratorPassword
  }
}

module logAnalytics 'modules/monitoring/loganalytics.bicep' = {
  name: 'loganalytics-${name}-${uniqueSuffix}-deployment'
  params: {
    logAnalyticsName: 'loganalytics-${name}-${uniqueSuffix}'
    location: location
    tags: tags
  }
}

module appIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'uai-app-${name}-${uniqueSuffix}-deployment'
  params: {
    name: 'uai-app-${name}-${uniqueSuffix}'
    location: location
  }
}

module registry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry-${name}-${uniqueSuffix}-deployment'
  params: {
    name: toLower(replace('registry-${name}-${uniqueSuffix}', '-', ''))
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    location: location
    tags: tags
    roleAssignments: [
      {
        principalId: appIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

module containerApp 'modules/containerapp.bicep' = {
  name: 'containerapp-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    tags: tags
    streamlitExists: streamlitExists
    containerAppName: 'pe-fe-${name}-${uniqueSuffix}'
    acrLoginServer: registry.outputs.loginServer
    acrContainerImage: acrContainerImage
    // If empty values for acrUsername and acrPassword, the system assigned identity
    // will be leveraged to pull from the ACR
    acrUsername: acrUsername
    acrPassword: acrPassword
    userAssignedIdentityId: appIdentity.outputs.resourceId
    containerEnvArray: [
      {
        name: 'AZURE_CLIENT_ID'
        value: appIdentity.outputs.clientId
      }
      {
        name: 'AZURE_OPENAI_KEY'
        value: openAiService.outputs.aiServicesKey
      }
      {
        name: 'AZURE_OPENAI_ENDPOINT'
        value: openAiService.outputs.aiServicesEndpoint
      }
      {
        name: 'AZURE_OPENAI_API_VERSION'
        value: openAiApiVersion
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
        value: embeddingModel.name
      }
      {
        name: 'AZURE_OPENAI_CHAT_DEPLOYMENT_ID'
        value: 'gpt-4o'
      }
      {
        name: 'AZURE_OPENAI_CHAT_DEPLOYMENT_01'
        value: 'gpt-4o'
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_DIMENSIONS'
        value: embeddingModelDimension
      }
      {
        name: 'AZURE_SEARCH_SERVICE_NAME'
        value: searchService.outputs.searchServiceName
      }
      {
        name: 'AZURE_SEARCH_INDEX_NAME'
        value: 'ai-policies-index'
      }
      {
        name: 'AZURE_AI_SEARCH_ADMIN_KEY'
        value: searchService.outputs.searchServicePrimaryKey
      }
      {
        name: 'AZURE_AI_SEARCH_SERVICE_ENDPOINT'
        value: searchService.outputs.searchServiceEndpoint
      }
      {
        name: 'AZURE_STORAGE_ACCOUNT_KEY'
        value: storageAccount.outputs.storageAccountPrimaryKey
      }
      {
        name: 'AZURE_BLOB_CONTAINER_NAME'
        value: storageBlobContainerName
      }
      {
        name: 'AZURE_STORAGE_ACCOUNT_NAME'
        value: storageAccount.outputs.storageAccountName
      }
      {
        name: 'AZURE_STORAGE_CONNECTION_STRING'
        value: storageAccount.outputs.storageAccountPrimaryConnectionString
      }
      {
        name: 'AZURE_AI_SERVICES_KEY'
        value: multiAccountAiServices.outputs.aiServicesPrimaryKey
      }
      {
        name: 'AZURE_COSMOS_DB_DATABASE_NAME'
        value: 'priorauthsessions'
      }
      {
        name: 'AZURE_COSMOS_DB_COLLECTION_NAME'
        value: 'temp'
      }
      {
        name: 'AZURE_COSMOS_CONNECTION_STRING'
        value: cosmosDb.outputs.mongoConnectionString
      }
      {
        name: 'AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT'
        value: docIntelligence.outputs.aiServiceDocIntelligenceEndpoint
      }
      {
        name: 'AZURE_DOCUMENT_INTELLIGENCE_KEY'
        value: docIntelligence.outputs.aiServicesKey
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.appInsightsConnectionString
      }
    ]
    environmentName: 'managedEnv-${name}-${uniqueSuffix}'
    appInsightsWorkspaceId: logAnalytics.outputs.logAnalyticsId
    workloadProfileName: 'Consumption'
  }
}
output AZURE_OPENAI_ENDPOINT string = openAiService.outputs.aiServicesEndpoint
output AZURE_OPENAI_API_VERSION string = openAiApiVersion
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT string = embeddingModel.name
output AZURE_OPENAI_CHAT_DEPLOYMENT_ID string = 'gpt-4o'
output AZURE_OPENAI_CHAT_DEPLOYMENT_01 string = 'gpt-4o'
output AZURE_OPENAI_EMBEDDING_DIMENSIONS string = embeddingModelDimension
output AZURE_SEARCH_SERVICE_NAME string = searchService.outputs.searchServiceName
output AZURE_SEARCH_INDEX_NAME string = 'ai-policies-index'
output AZURE_AI_SEARCH_ADMIN_KEY string = searchService.outputs.searchServicePrimaryKey
output AZURE_AI_SEARCH_SERVICE_ENDPOINT string = searchService.outputs.searchServiceEndpoint
output AZURE_STORAGE_ACCOUNT_KEY string = storageAccount.outputs.storageAccountPrimaryKey
output AZURE_BLOB_CONTAINER_NAME string = storageBlobContainerName
output AZURE_STORAGE_ACCOUNT_NAME string = storageAccount.outputs.storageAccountName
output AZURE_STORAGE_CONNECTION_STRING string = storageAccount.outputs.storageAccountPrimaryConnectionString
output AZURE_AI_SERVICES_KEY string = multiAccountAiServices.outputs.aiServicesPrimaryKey
output AZURE_COSMOS_DB_DATABASE_NAME string = 'priorauthsessions'
output AZURE_COSMOS_DB_COLLECTION_NAME string = 'temp'
output AZURE_COSMOS_CONNECTION_STRING string = cosmosDb.outputs.mongoConnectionString
output AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT string = docIntelligence.outputs.aiServicesEndpoint
output AZURE_DOCUMENT_INTELLIGENCE_KEY string = docIntelligence.outputs.aiServicesKey
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.outputs.appInsightsConnectionString
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_CONTAINER_ENVIRONMENT_ID string = containerApp.outputs.managedEnvironmentId
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApp.outputs.managedEnvironmentName

output appIdentityPrincipalId string = appIdentity.outputs.principalId
output appIdentityResourceId string = appIdentity.outputs.resourceId
output registryName string = registry.outputs.name
output containerAppName string = containerApp.outputs.containerAppName
output containerAppEndpoint string = containerApp.outputs.containerAppEndpoint
output logAnalyticsId string = logAnalytics.outputs.logAnalyticsId
output storageAccountName string = storageAccount.outputs.storageAccountName
output searchServiceName string = searchService.outputs.searchServiceName
output openAiServiceName string = openAiService.outputs.aiServicesName
output multiAccountAiServiceName string = multiAccountAiServices.outputs.aiServicesName
output docIntelligenceServiceName string = docIntelligence.outputs.aiServicesName
