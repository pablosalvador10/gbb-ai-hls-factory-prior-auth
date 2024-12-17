using './main.bicep'


param chatCompletionModels = [
  {
    name: 'gpt-4o'
    version: '2024-08-06'
    skuName: 'GlobalStandard'
    capacity: 25
  }
]
param embeddingModel = {
  name: 'text-embedding-3-large'
  version: '1'
  skuName: 'Standard'
  capacity: 16
}

param cosmosAdministratorPassword = readEnvironmentVariable('COSMOS_ADMINISTRATOR_PASSWORD', '')

param tags = {
  environment: readEnvironmentVariable('AZURE_ENV_NAME', 'development')
  project: 'priorAuth'
}
