@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Name of the Container App')
param containerAppName string

param acrLoginServer string

@description('Container Image for the Container App')
param acrContainerImage string

@description('Username for the Azure Container Registry (ACR)')
@minLength(0)
param acrUsername string = ''

@description('Password for the Azure Container Registry (ACR)')
@secure()
@minLength(0)
param acrPassword string = ''

@description('Key value env array for the Container App')
param containerEnvArray array

@description('Name of the Managed Environment')
param environmentName string

@description('ID of the Log Analytics Workspace')
param appInsightsWorkspaceId string

@description('Ingress configuration for the Container App.')
param ingressPort int = 8501

@description('Optional user-assigned identity for the Container App')
param userAssignedIdentityId string = ''

@description('SKU name for the Managed Environment. Allowed values: Consumption')
@allowed([
  'Consumption'
])
param workloadProfileName string = 'Consumption'

param streamlitExists bool = false
// Ensure names are lowercase to comply with Azure naming conventions
var containerAppNameCleaned = toLower(containerAppName)
var environmentNameCleaned = toLower(environmentName)
// var acrName = split(acrContainerImage, '/')[0]
var containerAppJobContributorRoleId = 'b9a307c4-5aa3-4b52-ba60-2b17c136cd7b'

// Append to containerEnvArray the AZURE_CLIENT_ID of the user-assigned-identity
var containerEnvArrayWithIdentity = union(containerEnvArray, [
  {
    name: 'AZURE_CLIENT_ID'
    value: appIdentity.outputs.principalId
  }
])

module containerFetchLatestImage './fetch-container-image.bicep' = {
  name: 'frontend-fetch-image'
  params: {
    exists: streamlitExists
    name: acrContainerImage
  }
}

var frontendContainer = {
  name: '${containerAppNameCleaned}-fe'
  image: containerFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
  command: []
  args: []
  resources: {
    cpu: json('2.0')
    memory: '4Gi'
  }
  env: containerEnvArrayWithIdentity
}

// var jobAppContainers = {
//   name: '${containerAppNameCleaned}-job'
//   image: containerFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
//   // command: ['/bin/bash', '-c', 'python /src/pipeline/indexerSetup.py --target \'/app\'']
//   command: ['/bin/bash', '-c', 'exit']
//   args: []
//   resources: {
//     cpu: json('2.0')
//     memory: '4Gi'
//   }
//   env: containerEnvArray
// }

var registries = acrUsername != '' && acrPassword != '' ? [{
  username: acrUsername
  passwordSecretRef: 'acr-password-secret'
  server: acrLoginServer
}] : userAssignedIdentityId != '' ? [{
  identity: userAssignedIdentityId
  server: acrLoginServer
}] : [{
  identity: 'system'
  server: acrLoginServer
}]

var secrets = acrPassword != '' ? [
  {
    name: 'acr-password-secret'
    value: acrPassword
  }
] : []

var ingress = {
  external: true
  transport: 'Auto'
  allowInsecure: false
  targetPort: ingressPort
  stickySessions: {
    affinity: 'none'
  }
  additionalPortMappings: []
}

// Resource: Managed Environment
resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: environmentNameCleaned
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(appInsightsWorkspaceId, '2020-08-01').customerId
        sharedKey: listKeys(appInsightsWorkspaceId, '2020-08-01').primarySharedKey
      }
    }
    publicNetworkAccess: 'Enabled'
    workloadProfiles: [
      {
        name: workloadProfileName
        workloadProfileType: workloadProfileName
      }
    ]
  }
}

// resource containerAppJob 'Microsoft.App/jobs@2024-02-02-preview' = {
//   name: '${containerAppNameCleaned}-job'
//   location: location
//   tags: union(tags, { 'azd-service-name': 'streamlit' })
//   properties: {
//     environmentId: managedEnvironment.id
//     configuration: {
//       secrets: secrets
//       registries: registries
//       replicaTimeout: 7200
//       replicaRetryLimit: 3
//       triggerType: 'Manual'
//       manualTriggerConfig: {
//         replicaCompletionCount: 1
//         parallelism: 1
//       }
//     }
//     template: {
//       containers: [jobAppContainers]
//     }
//     workloadProfileName: workloadProfileName
//   }
// }

// resource containerAppJobContributorRoleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
//   scope: resourceGroup()
//   name: containerAppJobContributorRoleId
// }

// resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
//   name: 'script-identity'
//   location: location
// }

// resource jobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: containerAppJob
//   name: guid(containerAppJobContributorRoleDef.id, scriptIdentity.id, containerAppJob.id)
//   properties: {
//     principalType: 'ServicePrincipal'
//     principalId: scriptIdentity.properties.principalId
//     roleDefinitionId: containerAppJobContributorRoleDef.id
//   }
// }

// resource triggerJobScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
//   name: '${containerAppNameCleaned}-trigger'
//   location: location
//   kind: 'AzureCLI'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${scriptIdentity.id}': {}
//     }
//   }
//   properties: {
//     azCliVersion: '2.59.0'
//     arguments: '${containerAppJob.name} ${resourceGroup().name}'
//     retentionInterval: 'PT1H'
//     scriptContent: '''
//       #!/bin/bash
//       set -e
//       az containerapp job start -n $1 -g $2
//     '''
//   }
//   dependsOn: [
//     containerAppJob
//   ]
// }

module appIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: '${containerAppNameCleaned}-uaidentity'
  params: {
    name: '${containerAppNameCleaned}-uaidentity'
    location: location
  }
}

// Resource: Container App
resource containerAppResource 'Microsoft.App/containerapps@2024-02-02-preview' = {
  name: containerAppNameCleaned
  kind: 'containerapps'
  location: location
  tags: union(tags, { 'azd-service-name': 'streamlit' })
  identity: userAssignedIdentityId != '' ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  } : {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: managedEnvironment.id
    configuration: {
      secrets: secrets
      registries: registries
      activeRevisionsMode: 'Single'
      ingress: ingress
    }
    template: {
      containers: [frontendContainer]
      scale: {
        minReplicas: 0
      }
    }
    workloadProfileName: workloadProfileName
  }
}

// Outputs
output containerAppIdentityPrincipalId string = userAssignedIdentityId != '' ? userAssignedIdentityId : containerAppResource.identity.principalId
output containerAppEndpoint string = containerAppResource.properties.configuration.ingress.fqdn
output containerAppId string = containerAppResource.id
output containerAppName string = containerAppResource.name
output managedEnvironmentId string = managedEnvironment.id
output managedEnvironmentName string = managedEnvironment.name
