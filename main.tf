terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

# Define variables for Azure authentication and configuration
variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_client_id" {
  description = "Azure Client ID (Service Principal)"
  type        = string
}

variable "azure_client_secret" {
  description = "Azure Client Secret (Service Principal)"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "langflow-aks-rg"
}

variable "location" {
  description = "Azure Region for resources"
  type        = string
  default     = "East US"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "langflow-aks"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B4ms"  # 4 vCPUs, 16 GB RAM - budget-friendly burstable
}

# Configure the Azure Provider with variables
provider "azurerm" {
  features {}
  
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

# Create a resource group
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create an AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "langflow"
  kubernetes_version  = "1.32"  # Specify a supported version

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_size
    os_disk_size_gb = 128  # Set an appropriate OS disk size
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Application = "Langflow"
  }
}

# Configure Kubernetes provider to use AKS credentials
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

# Configure Helm provider to use AKS credentials
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

# Create namespace for Langflow
resource "kubernetes_namespace" "langflow" {
  metadata {
    name = "langflow"
  }
}

# Install Langflow IDE using the Helm chart
resource "helm_release" "langflow_ide" {
  name       = "langflow-ide"
  repository = "https://langflow-ai.github.io/langflow-helm-charts"
  chart      = "langflow-ide"
  namespace  = kubernetes_namespace.langflow.metadata[0].name
  
  # Depends on the namespace being created first
  depends_on = [
    kubernetes_namespace.langflow
  ]
  
  # You can add custom values here if needed
  values = [
    file("${path.module}/values.yaml")
  ]
  
  # Or set individual values
  # set {
  #   name  = "service.type"
  #   value = "LoadBalancer"  # Changed to LoadBalancer to expose the service externally
  # }
}

# Output the AKS cluster information
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  value = azurerm_resource_group.aks_rg.name
}

# Output Langflow endpoint information
output "langflow_endpoint" {
  value = "Use 'kubectl get svc -n ${kubernetes_namespace.langflow.metadata[0].name}' to get the Langflow endpoint"
}