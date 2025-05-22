#!/bin/bash

# Azure Container Apps Deployment Script for CCUS Agent
# This script deploys the Streamlit app to Azure Container Apps

set -e  # Exit on any error

# Configuration variables
RESOURCE_GROUP="ccus-agent-rg"
LOCATION="eastus2"
CONTAINER_REGISTRY_NAME="ccusagentregistry"
CONTAINER_APP_ENV="ccus-agent-env"
CONTAINER_APP_NAME="ccus-agent-app"
IMAGE_NAME="ccus-agent"
IMAGE_TAG="latest"

echo "🚀 Starting deployment to Azure Container Apps..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo "📝 Please login to Azure..."
    az login
fi

echo "✅ Azure CLI authenticated"

# Install Container Apps extension if not already installed
echo "🔧 Installing/updating Azure Container Apps CLI extension..."
az extension add --name containerapp --upgrade

# Create resource group
echo "📦 Creating resource group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output table

# Create Azure Container Registry
echo "🐳 Creating Azure Container Registry: $CONTAINER_REGISTRY_NAME"
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_REGISTRY_NAME \
    --sku Standard \
    --location $LOCATION \
    --admin-enabled true \
    --output table

# Build and push the container image using ACR Tasks
echo "🏗️  Building and pushing container image..."
az acr build \
    --registry $CONTAINER_REGISTRY_NAME \
    --image $IMAGE_NAME:$IMAGE_TAG \
    --file Dockerfile \
    . \
    --output table

# Create Container Apps environment
echo "🌍 Creating Container Apps environment: $CONTAINER_APP_ENV"
az containerapp env create \
    --name $CONTAINER_APP_ENV \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --output table

# Get the Container Registry login server
REGISTRY_SERVER=$(az acr show --name $CONTAINER_REGISTRY_NAME --query loginServer --output tsv)
echo "📍 Registry server: $REGISTRY_SERVER"

# Get Container Registry credentials
REGISTRY_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query username --output tsv)
REGISTRY_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query passwords[0].value --output tsv)

# Create the Container App
echo "🚀 Deploying Container App: $CONTAINER_APP_NAME"
az containerapp create \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINER_APP_ENV \
    --image "$REGISTRY_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
    --registry-server $REGISTRY_SERVER \
    --registry-username $REGISTRY_USERNAME \
    --registry-password $REGISTRY_PASSWORD \
    --target-port 8501 \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 10 \
    --cpu 0.5 \
    --memory 1.0Gi \
    --env-vars \
        STREAMLIT_SERVER_PORT=8501 \
        STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    --output table

# Get the application URL
APP_URL=$(az containerapp show \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo ""
echo "🎉 Deployment completed successfully!"
echo "📱 Your CCUS Agent app is available at: https://$APP_URL"
echo ""
echo "🔧 Useful commands:"
echo "   View logs: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo "   Update app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image $REGISTRY_SERVER/$IMAGE_NAME:$IMAGE_TAG"
echo "   Scale app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 20"
echo ""
echo "💡 Note: The app scales to zero when not in use, so the first request might take a moment to start up." 