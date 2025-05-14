# Langflow on AKS

This repository contains Terraform configurations to deploy Langflow on Azure Kubernetes Service (AKS).

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [Terraform](https://www.terraform.io/downloads.html) installed (v1.0.0+)
- Azure subscription
- Service Principal with Contributor access to your Azure subscription

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/langflow-aks.git
cd langflow-aks
```

### 2. Configure your Azure credentials

Create a copy of the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```
Open `terraform.tfvars` in your editor and replace the placeholder values with your actual Azure credentials:

### 3. Initialize Terraform an run the plan

```bash
terraform init
terraform plan 
terraform apply 
```

This will create:
- A resource group
- An AKS cluster
- A Kubernetes namespace for Langflow
- The Langflow deployment via Helm

The deployment process takes approximately 10-15 minutes.

## Accessing Langflow

After deployment completes, you can access Langflow using these steps:

1. Get AKS credentials:
   ```bash
   az aks get-credentials --resource-group langflow-aks-rg --name langflow-aks
   ```

2. Check the Langflow service:
   ```bash
   kubectl get svc -n langflow
   ```

3. Access the Langflow UI using the `EXTERNAL-IP` from the service output.

## Customization

To customize the Langflow deployment, modify the `values.yaml` file.

## Cleanup

To delete all resources:

```bash
terraform destroy
```

