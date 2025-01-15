#!/bin/bash

echo "Generating .env file..."
echo "
AZURE_OPENAI_ENDPOINT=$(azd env get-value AZURE_OPENAI_ENDPOINT)
AZURE_OPENAI_API_VERSION=$(azd env get-value AZURE_OPENAI_API_VERSION)
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=$(azd env get-value AZURE_OPENAI_EMBEDDING_DEPLOYMENT)
AZURE_OPENAI_KEY=$(azd env get-value AZURE_OPENAI_KEY)
AZURE_OPENAI_CHAT_DEPLOYMENT_ID=$(azd env get-value AZURE_OPENAI_CHAT_DEPLOYMENT_ID)
AZURE_OPENAI_EMBEDDING_DIMENSIONS=$(azd env get-value AZURE_OPENAI_EMBEDDING_DIMENSIONS)
AZURE_SEARCH_SERVICE_NAME=$(azd env get-value AZURE_SEARCH_SERVICE_NAME)
AZURE_SEARCH_INDEX_NAME=$(azd env get-value AZURE_SEARCH_INDEX_NAME)
AZURE_AI_SEARCH_SERVICE_ENDPOINT=$(azd env get-value AZURE_AI_SEARCH_SERVICE_ENDPOINT)
AZURE_AI_SEARCH_ADMIN_KEY=$(azd env get-value AZURE_AI_SEARCH_ADMIN_KEY)
AZURE_BLOB_CONTAINER_NAME=$(azd env get-value AZURE_BLOB_CONTAINER_NAME)
AZURE_STORAGE_ACCOUNT_NAME=$(azd env get-value AZURE_STORAGE_ACCOUNT_NAME)
AZURE_OPENAI_CHAT_DEPLOYMENT_01=$(azd env get-value AZURE_OPENAI_CHAT_DEPLOYMENT_01)
AZURE_STORAGE_ACCOUNT_KEY=$(azd env get-value AZURE_STORAGE_ACCOUNT_KEY)
AZURE_AI_SERVICES_KEY=$(azd env get-value AZURE_AI_SERVICES_KEY)
AZURE_STORAGE_CONNECTION_STRING=$(azd env get-value AZURE_STORAGE_CONNECTION_STRING)
AZURE_COSMOS_DB_DATABASE_NAME=$(azd env get-value AZURE_COSMOS_DB_DATABASE_NAME)
AZURE_COSMOS_DB_COLLECTION_NAME=$(azd env get-value AZURE_COSMOS_DB_COLLECTION_NAME)
AZURE_COSMOS_CONNECTION_STRING=$(azd env get-value AZURE_COSMOS_CONNECTION_STRING)
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=$(azd env get-value AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT)
AZURE_DOCUMENT_INTELLIGENCE_KEY=$(azd env get-value AZURE_DOCUMENT_INTELLIGENCE_KEY)
APPLICATIONINSIGHTS_CONNECTION_STRING=$(azd env get-value APPLICATIONINSIGHTS_CONNECTION_STRING)
AZURE_CONTAINER_REGISTRY_ENDPOINT=$(azd env get-value AZURE_CONTAINER_REGISTRY_ENDPOINT)
" > .env

echo "Checking if the post-deployment job needs to be run..."
if [ -z "$(azd env get-value SERVICE_FRONTEND_IMAGE_NAME)" ]; then
    echo "Backend image does not exist. Clearing CONTAINER_JOB_RUN value..."
    azd env set CONTAINER_JOB_RUN false
fi
