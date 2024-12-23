@minLength(2)
@maxLength(12)
@description('Name for the PriorAuth resource and used to derive the name of dependent resources.')
param priorAuthName string = 'priorAuth'

@description('Set of tags to apply to all resources.')
param tags object = {}

@description('ACR container image url')
param acrContainerImage string = 'msftpriorauth.azurecr.io/priorauth-frontend:v2'

@description('Admin user for the ACR registry of the container image')
@secure()
param acrUsername string = ''

@description('Admin password for the ACR registry of the container image')
@secure()
param acrPassword string = ''

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

@description('AAD Client ID (App Registration ID) for the Container App.')
param aadClientId string = ''

@description('AAD Client Secret for the Container App.')
@secure()
param aadClientSecret string = ''

@description('AAD Tenant ID for the Container App.')
param aadTenantId string = ''

@description('Allowed provider scope for the identity. Only Microsoft AAD is currently supported. Also only select if plan on provisioning with Entra account, personal accounts do not have required permissions.')
@allowed([
  'aad' // Microsoft Azure Active Directory
  'none' // Placeholder for future support (e.g., Google, GitHub)
])
param authProvider string = 'none'

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

module containerApp 'modules/compute/containerapp.bicep' = {
  name: 'containerapp-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    tags: tags
    containerAppName: 'pe-fe-${name}-${uniqueSuffix}'
    acrContainerImage: acrContainerImage
    acrUsername: acrUsername
    acrPassword: acrPassword
    authProvider: authProvider
    aadClientId: aadClientId
    aadTenantId: aadTenantId
    aadClientSecret: aadClientSecret
    containerEnvArray: [
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
