# CCUS Agent - Azure Container Apps Deployment

A Streamlit-based Carbon Capture, Utilization, and Storage (CCUS) agent application deployed on Azure Container Apps.

## Why Azure Container Apps (Not Function Apps)?

While you initially asked about Azure Function Apps, **Azure Container Apps is the recommended choice** for Streamlit applications because:

- **Function Apps limitations**: Function Apps are designed for serverless functions with execution time limits and don't support persistent web servers like Streamlit
- **Streamlit requirements**: Streamlit uses WebSockets and runs as a persistent web server using Tornado
- **Container Apps benefits**: 
  - Scales to zero when not in use (cost-effective)
  - Supports persistent web applications
  - Built-in load balancing and SSL
  - Easy container deployment
  - Can scale to hundreds of replicas

## Architecture

```
Internet → Azure Container Apps → Streamlit App → Azure AI Projects
```

## Prerequisites

1. **Azure CLI** - [Download and install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Azure Subscription** with permissions to create:
   - Resource Groups
   - Azure Container Registry
   - Azure Container Apps
3. **Docker** (optional - we use Azure Container Registry Tasks for building)

## Quick Deployment

### Option 1: One-Click Deployment (PowerShell - Windows)

```powershell
.\deploy.ps1
```

### Option 2: One-Click Deployment (Bash - Linux/Mac/WSL)

```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 3: Manual Deployment

1. **Install Azure CLI extensions**:
   ```bash
   az extension add --name containerapp --upgrade
   ```

2. **Login to Azure**:
   ```bash
   az login
   ```

3. **Set variables** (modify as needed):
   ```bash
   RESOURCE_GROUP="ccus-agent-rg"
   LOCATION="eastus2"
   CONTAINER_REGISTRY_NAME="ccusagentregistry"
   CONTAINER_APP_ENV="ccus-agent-env"
   CONTAINER_APP_NAME="ccus-agent-app"
   ```

4. **Create resource group**:
   ```bash
   az group create --name $RESOURCE_GROUP --location $LOCATION
   ```

5. **Create Container Registry**:
   ```bash
   az acr create \
     --resource-group $RESOURCE_GROUP \
     --name $CONTAINER_REGISTRY_NAME \
     --sku Standard \
     --admin-enabled true
   ```

6. **Build and push container**:
   ```bash
   az acr build \
     --registry $CONTAINER_REGISTRY_NAME \
     --image ccus-agent:latest \
     --file Dockerfile .
   ```

7. **Create Container Apps environment**:
   ```bash
   az containerapp env create \
     --name $CONTAINER_APP_ENV \
     --resource-group $RESOURCE_GROUP \
     --location $LOCATION
   ```

8. **Deploy the app**:
   ```bash
   # Get registry details
   REGISTRY_SERVER=$(az acr show --name $CONTAINER_REGISTRY_NAME --query loginServer --output tsv)
   REGISTRY_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query username --output tsv)
   REGISTRY_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query passwords[0].value --output tsv)

   # Create container app
   az containerapp create \
     --name $CONTAINER_APP_NAME \
     --resource-group $RESOURCE_GROUP \
     --environment $CONTAINER_APP_ENV \
     --image "$REGISTRY_SERVER/ccus-agent:latest" \
     --registry-server $REGISTRY_SERVER \
     --registry-username $REGISTRY_USERNAME \
     --registry-password $REGISTRY_PASSWORD \
     --target-port 8501 \
     --ingress external \
     --min-replicas 0 \
     --max-replicas 10 \
     --cpu 0.5 \
     --memory 1.0Gi
   ```

## Configuration

### Environment Variables

The app uses these environment variables (automatically set by deployment scripts):

- `STREAMLIT_SERVER_PORT=8501` - Port for Streamlit server
- `STREAMLIT_SERVER_ADDRESS=0.0.0.0` - Address to bind to

### Scaling Configuration

- **Min Replicas**: 0 (scales to zero when not in use)
- **Max Replicas**: 10 (can handle burst traffic)
- **CPU**: 0.5 cores per replica
- **Memory**: 1GB per replica

### Ingress Configuration

- **External ingress**: Enabled (publicly accessible)
- **Target Port**: 8501 (Streamlit default port)
- **HTTPS**: Automatically enabled with managed certificates

## Monitoring and Management

### View Application Logs
```bash
az containerapp logs show \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --follow
```

### Update Application
```bash
# After making changes, rebuild and update
az acr build --registry ccusagentregistry --image ccus-agent:latest .

# Update the container app
az containerapp update \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --image ccusagentregistry.azurecr.io/ccus-agent:latest
```

### Scale Application
```bash
# Scale up for high traffic
az containerapp update \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --min-replicas 2 \
  --max-replicas 20

# Scale down for cost optimization
az containerapp update \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --min-replicas 0 \
  --max-replicas 5
```

## Cost Optimization

Azure Container Apps is cost-effective because:

1. **Scale to Zero**: App stops running when not in use
2. **Pay-per-use**: Only pay for actual consumption
3. **Efficient scaling**: Automatically scales based on demand
4. **No idle costs**: No charges when scaled to zero

Estimated costs for typical usage:
- **Light usage** (< 1000 requests/month): $1-5/month
- **Medium usage** (10K-100K requests/month): $10-50/month
- **Heavy usage** (1M+ requests/month): $100-500/month

## Troubleshooting

### Common Issues

1. **Container Registry name conflicts**:
   - Registry names must be globally unique
   - Modify `CONTAINER_REGISTRY_NAME` in deployment scripts

2. **Resource Group exists**:
   - The script will use existing resource groups
   - Ensure you have permissions in the target resource group

3. **Authentication issues**:
   - Run `az login` to authenticate
   - Ensure you have Contributor permissions on the subscription

4. **Container build failures**:
   - Check Dockerfile syntax
   - Ensure requirements.txt is valid
   - Check Azure CLI version

### View Deployment Status
```bash
# Check container app status
az containerapp show \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --query properties.runningStatus

# Check recent deployments
az containerapp revision list \
  --name ccus-agent-app \
  --resource-group ccus-agent-rg \
  --output table
```

## Security Considerations

1. **Container Registry**: Uses admin credentials (suitable for development)
2. **Managed Identity**: Consider using managed identity for production
3. **Network Security**: App is publicly accessible by default
4. **Environment Variables**: Sensitive data should use Azure Key Vault references

## Next Steps

1. **Custom Domain**: Add your own domain name
2. **Authentication**: Enable Azure Active Directory authentication
3. **Monitoring**: Set up Application Insights for detailed monitoring
4. **CI/CD**: Implement GitHub Actions or Azure DevOps pipelines
5. **Scaling Rules**: Configure custom scaling rules based on metrics

## Support

For issues related to:
- **Azure Container Apps**: [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- **Streamlit**: [Streamlit Documentation](https://docs.streamlit.io/)
- **Azure AI Projects**: [Azure AI Services Documentation](https://docs.microsoft.com/en-us/azure/ai-services/)

## File Structure

```
.
├── agent_app.py           # Main Streamlit application
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container definition
├── .dockerignore         # Docker ignore rules
├── deploy.sh             # Bash deployment script
├── deploy.ps1            # PowerShell deployment script
├── deploy-to-azure.yaml  # Deployment configuration
└── README.md             # This file
``` 