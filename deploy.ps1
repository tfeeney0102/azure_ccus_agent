# Azure Container Apps Deployment Script for CCUS Agent (PowerShell)
# This script deploys the Streamlit app to Azure Container Apps

$ErrorActionPreference = "Stop"

# Configuration variables
$RESOURCE_GROUP = "ccus-agent-rg"
$LOCATION = "eastus2"
$CONTAINER_REGISTRY_NAME = "ccusagentregistry"
$CONTAINER_APP_ENV = "ccus-agent-env"
$CONTAINER_APP_NAME = "ccus-agent-app"
$IMAGE_NAME = "ccus-agent"
$IMAGE_TAG = "latest"

Write-Host "🚀 Starting deployment to Azure Container Apps..." -ForegroundColor Green

# Check if Azure CLI is installed
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if user is logged in
try {
    az account show | Out-Null
    Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
} catch {
    Write-Host "📝 Please login to Azure..." -ForegroundColor Yellow
    az login
}

# Install Container Apps extension if not already installed
Write-Host "🔧 Installing/updating Azure Container Apps CLI extension..." -ForegroundColor Yellow
az extension add --name containerapp --upgrade

# Create resource group
Write-Host "📦 Creating resource group: $RESOURCE_GROUP" -ForegroundColor Yellow
az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION `
    --output table

# Create Azure Container Registry
Write-Host "🐳 Creating Azure Container Registry: $CONTAINER_REGISTRY_NAME" -ForegroundColor Yellow
az acr create `
    --resource-group $RESOURCE_GROUP `
    --name $CONTAINER_REGISTRY_NAME `
    --sku Standard `
    --location $LOCATION `
    --admin-enabled true `
    --output table

# Build and push the container image using ACR Tasks
Write-Host "🏗️  Building and pushing container image..." -ForegroundColor Yellow
az acr build `
    --registry $CONTAINER_REGISTRY_NAME `
    --image "${IMAGE_NAME}:${IMAGE_TAG}" `
    --file Dockerfile `
    . `
    --output table

# Create Container Apps environment
Write-Host "🌍 Creating Container Apps environment: $CONTAINER_APP_ENV" -ForegroundColor Yellow
az containerapp env create `
    --name $CONTAINER_APP_ENV `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --output table

# Get the Container Registry login server
$REGISTRY_SERVER = az acr show --name $CONTAINER_REGISTRY_NAME --query loginServer --output tsv
Write-Host "📍 Registry server: $REGISTRY_SERVER" -ForegroundColor Cyan

# Get Container Registry credentials
$REGISTRY_USERNAME = az acr credential show --name $CONTAINER_REGISTRY_NAME --query username --output tsv
$REGISTRY_PASSWORD = az acr credential show --name $CONTAINER_REGISTRY_NAME --query passwords[0].value --output tsv

# Create the Container App
Write-Host "🚀 Deploying Container App: $CONTAINER_APP_NAME" -ForegroundColor Yellow
az containerapp create `
    --name $CONTAINER_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --environment $CONTAINER_APP_ENV `
    --image "$REGISTRY_SERVER/${IMAGE_NAME}:${IMAGE_TAG}" `
    --registry-server $REGISTRY_SERVER `
    --registry-username $REGISTRY_USERNAME `
    --registry-password $REGISTRY_PASSWORD `
    --target-port 8501 `
    --ingress external `
    --min-replicas 0 `
    --max-replicas 10 `
    --cpu 0.5 `
    --memory 1.0Gi `
    --env-vars `
        STREAMLIT_SERVER_PORT=8501 `
        STREAMLIT_SERVER_ADDRESS=0.0.0.0 `
    --output table

# Get the application URL
$APP_URL = az containerapp show `
    --name $CONTAINER_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query properties.configuration.ingress.fqdn `
    --output tsv

Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "📱 Your CCUS Agent app is available at: https://$APP_URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔧 Useful commands:" -ForegroundColor Yellow
Write-Host "   View logs: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
Write-Host "   Update app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image $REGISTRY_SERVER/${IMAGE_NAME}:${IMAGE_TAG}"
Write-Host "   Scale app: az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --min-replicas 1 --max-replicas 20"
Write-Host ""
Write-Host "💡 Note: The app scales to zero when not in use, so the first request might take a moment to start up." -ForegroundColor Blue 