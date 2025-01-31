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



# This resource block creates an Azure Virtual Network (VNet).
# A VNet is a logical isolation of the Azure cloud dedicated to your subscription.
# It enables Azure resources to securely communicate with each other, the internet, and on-premises networks.
#
# The VNet is named "vnet-avd-int-westeu" and is located in the region specified by the 'location2' variable.
# - address_space: The address space for the VNet, defined as "10.0.0.0/16"
resource "azurerm_virtual_network" "avd_vnet" {
  name                = "vnet-avd-int-westeu"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name
  address_space       = ["10.0.0.0/16"]
}

# This resource block creates a Subnet within an Azure Virtual Network (VNet).
# A subnet is a range of IP addresses in the VNet. Subnets allow you to segment the VNet into smaller, manageable sections.
# They enable Azure resources to communicate with each other and with the internet.
resource "azurerm_subnet" "avd_subnet" {
  name                 = "snet-avd"
  resource_group_name  = azurerm_resource_group.rg-avd.name
  virtual_network_name = azurerm_virtual_network.avd_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


# This resource block creates Network Interfaces (NICs) for Virtual Machines (VMs).
# NICs are used to connect VMs to a virtual network, enabling communication with other resources.
#
# The block creates 2 NICs.
resource "azurerm_network_interface" "avd_nic" {
  count               = 2 # Number of VMs
  name                = "nic-avd-${count.index + 1}"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avd_subnet.id # Now it exists!
    private_ip_address_allocation = "Dynamic"
  }
}