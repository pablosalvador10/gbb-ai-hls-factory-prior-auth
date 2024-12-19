targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string


@description('Admin password for the cluster')
@secure()
param cosmosAdministratorPassword string

@minLength(2)
@maxLength(12)
@description('Name for the PriorAuth resource and used to derive the name of dependent resources.')
param priorAuthName string = 'priorAuth'

@description('ACR container image url')
@secure()
param acrContainerImage string = ''

@description('Admin user for the ACR registry of the container image')
@secure()
@minLength(0)
param acrUsername string = ''

@description('Admin password for the ACR registry of the container image')
@secure()
@minLength(0)
param acrPassword string = ''


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
    name: 'text-embedding-3-large'
    version: '1'
    skuName: 'Standard'
    capacity: 16
}

@description('Embedding model size for the OpenAI Embedding deployment')
param embeddingModelDimension string = '1536'

@description('Storage Blob Container name to land the files for Prior Auth')
param storageBlobContainerName string = 'default'
// Tags that should be applied to all resources.
//
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${priorAuthName}-${location}-${environmentName}'
  location: location
  tags: tags
}

module resources 'priorAuthInfra.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    // Required Parameters
    tags: tags
    cosmosAdministratorPassword: cosmosAdministratorPassword

    // Optional Parameters
    priorAuthName: priorAuthName
    acrContainerImage: acrContainerImage
    acrUsername: acrUsername
    acrPassword: acrPassword
    openAiApiVersion: openAiApiVersion
    chatCompletionModels: chatCompletionModels
    embeddingModel: embeddingModel
    embeddingModelDimension: embeddingModelDimension
    storageBlobContainerName: storageBlobContainerName
  }
}

output RESOURCE_GROUP_NAME string = rg.name
output APP_UAI_PRINCIPAL_ID string = resources.outputs.appIdentityPrincipalId
output APP_UAI_RESOURCE_ID string = resources.outputs.appIdentityResourceId
output REGISTRY_NAME string = resources.outputs.registryName

output AZURE_OPENAI_ENDPOINT string = resources.outputs.AZURE_OPENAI_ENDPOINT
output AZURE_OPENAI_API_VERSION string = resources.outputs.AZURE_OPENAI_API_VERSION
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT string = resources.outputs.AZURE_OPENAI_EMBEDDING_DEPLOYMENT
output AZURE_OPENAI_CHAT_DEPLOYMENT_ID string = resources.outputs.AZURE_OPENAI_CHAT_DEPLOYMENT_ID
output AZURE_OPENAI_CHAT_DEPLOYMENT_01 string = resources.outputs.AZURE_OPENAI_CHAT_DEPLOYMENT_01
output AZURE_OPENAI_EMBEDDING_DIMENSIONS string = resources.outputs.AZURE_OPENAI_EMBEDDING_DIMENSIONS
output AZURE_SEARCH_SERVICE_NAME string = resources.outputs.AZURE_SEARCH_SERVICE_NAME
output AZURE_SEARCH_INDEX_NAME string = resources.outputs.AZURE_SEARCH_INDEX_NAME
output AZURE_AI_SERVICES_ENDPOINT string = resources.outputs.AZURE_AI_SEARCH_SERVICE_ENDPOINT
output AZURE_AI_SEARCH_ADMIN_KEY string = resources.outputs.AZURE_AI_SEARCH_ADMIN_KEY
output AZURE_BLOB_CONTAINER_NAME string = resources.outputs.AZURE_BLOB_CONTAINER_NAME
output AZURE_STORAGE_ACCOUNT_NAME string = resources.outputs.AZURE_STORAGE_ACCOUNT_NAME
output AZURE_STORAGE_ACCOUNT_KEY string = resources.outputs.AZURE_STORAGE_ACCOUNT_KEY
output AZURE_STORAGE_CONNECTION_STRING string = resources.outputs.AZURE_STORAGE_CONNECTION_STRING
output AZURE_AI_SERVICES_KEY string = resources.outputs.AZURE_AI_SERVICES_KEY
output AZURE_COSMOS_DB_DATABASE_NAME string = resources.outputs.AZURE_COSMOS_DB_DATABASE_NAME
output AZURE_COSMOS_DB_COLLECTION_NAME string = resources.outputs.AZURE_COSMOS_DB_COLLECTION_NAME
output AZURE_COSMOS_CONNECTION_STRING string = resources.outputs.AZURE_COSMOS_CONNECTION_STRING
output AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT string = resources.outputs.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT
output AZURE_DOCUMENT_INTELLIGENCE_KEY string = resources.outputs.AZURE_DOCUMENT_INTELLIGENCE_KEY
output APPLICATIONINSIGHTS_CONNECTION_STRING string = resources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_ENVIRONMENT_ID string = resources.outputs.AZURE_CONTAINER_ENVIRONMENT_ID
