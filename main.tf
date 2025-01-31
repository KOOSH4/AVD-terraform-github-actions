terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }

  # Update this block with the location of your terraform state file.
  backend "azurerm" {
    resource_group_name  = "rg-AVD-int-dewc-2"
    storage_account_name = "stavdtfdewc2"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
}
# This resource block defines an Azure Resource Group named "rg-AVD-int-dewc-1"
resource "azurerm_resource_group" "rg-avd" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Location = "germanywestcentral"
    Owner    = "Olad, Koosha"
  }
}
# This resource block defines an Azure Virtual Desktop (AVD) Host Pool.
# A host pool is a collection of one or more identical virtual machines (VMs) within the AVD environment.
# It is used to manage and provide virtual desktops to users.
#
# The host pool is named "hp-avd-int-dewc-1" and is located in the "westeurope" region.
# It is associated with the specified resource group and has the following configurations:
# - type: Defined by the variable 'host_pool_type' (either "Pooled" or "Personal")
# - load_balancer_type: Defined by the variable 'load_balancer_type' (e.g., "DepthFirst")
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                = "hp-avd-int-dewc-1"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-avd.name

  type               = var.host_pool_type
  load_balancer_type = var.load_balancer_type
  // validation_environment = true  # Set to "true" for production
  friendly_name = "AVD Host Pool - Production"
  description   = "Host pool for remote desktops"
}

# This resource block defines an Azure Virtual Desktop (AVD) Application Group.
# An application group is a logical grouping of applications that can be assigned to users.
# It is used to manage and publish applications to users in a virtual desktop environment.
# 
# The application group is named "ag-avd-int-dewc-1" and is located in the region specified by the 'location' variable.
# It is associated with the specified resource group and host pool, and is of type "Desktop".
resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "ag-avd-int-dewc-1"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-avd.name
  type                = "Desktop" # Options: "Desktop" or "RemoteApp"
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
}

# This resource block defines an Azure Virtual Desktop (AVD) Workspace.
# A workspace is a logical container for managing and providing access to virtual desktops and applications.
# It serves as a central hub where users can access their assigned desktops and applications.
resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "ws-avd-dewc-1"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg-avd.name
  friendly_name       = "AVD Workspace"
  description         = "Workspace for AVD environment"
}
# This resource block creates an association between an Azure Virtual Desktop (AVD) Workspace and an Application Group.
# This association links the specified workspace to the application group, allowing users to access the applications within the group through the workspace.
#
# The association is defined by the IDs of the workspace and the application group.
resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_association" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}