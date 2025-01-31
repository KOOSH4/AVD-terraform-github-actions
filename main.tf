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

# This resource block creates Azure Virtual Desktop (AVD) Session Host Virtual Machines (VMs).
# Session Host VMs are the virtual machines that users connect to in order to access their virtual desktops and applications.
# They are configured with the necessary resources and settings to support multiple user sessions.
#
# This example creates 2 VMs, each with the specified configurations:
# - name: The name of the VM, dynamically generated based on the count index
# - resource_group_name: The name of the resource group
# - location: The region where the VMs are deployed
# - size: The size of the VM, defined in variables.tf
# - admin_username: The administrator username for the VM
# - admin_password: The administrator password for the VM (use GitHub Secrets for this)
# - network_interface_ids: The IDs of the network interfaces associated with the VMs
# - os_disk: The configuration for the OS disk, including caching and storage account type
resource "azurerm_windows_virtual_machine" "avd_vm" {
  count                 = 2 # Adjust the number of VMs
  name                  = "vm-avd-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.rg-avd.name
  location              = var.location2
  size                  = var.vm_size # Define in variables.tf
  admin_username        = var.admin_username
  admin_password        = var.admin_password # Use GitHub Secrets for this
  network_interface_ids = [azurerm_network_interface.avd_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }
}

# This resource block creates Network Interfaces (NICs) for Virtual Machines (VMs).
# NICs are used to connect VMs to a virtual network, enabling communication with other resources.
#
# The block creates 2 NICs with the following configurations:
# - count: The number of NICs to create
# - name: The name of the NIC, dynamically generated based on the count index
# - location: The region where the NICs are deployed
# - resource_group_name: The name of the resource group
# - ip_configuration: The IP configuration for the NICs, including subnet ID and private IP address allocation
resource "azurerm_network_interface" "avd_nic" {
  count               = 2
  name                = "nic-avd-${count.index + 1}"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id # Define subnet ID in variables.tf
    private_ip_address_allocation = "Dynamic"
  }
}

# This resource block registers Virtual Machines (VMs) with the Azure Virtual Desktop (AVD) Host Pool.
# Registration allows the VMs to be recognized and managed as part of the host pool, enabling user access to virtual desktops.
#
# The block specifies the host pool ID and sets an expiration date for the registration token.
# - hostpool_id: The ID of the AVD host pool
# - expiration_date: The expiration date for the registration token, set to 24 hours from the current time
resource "azurerm_virtual_desktop_host_pool_registration_info" "avd_registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "24h") # Token valid for 24 hours
}


# This resource block defines an Azure Network Security Group (NSG).
# An NSG is used to control inbound and outbound traffic to network interfaces (NICs), VMs, and subnets.
# It contains security rules that allow or deny network traffic based on source and destination IP addresses, ports, and protocols.
#
# The NSG is named "nsg-avd" and is located in the region specified by the 'location' variable.
# It is associated with the specified resource group and has the following security rule:
# - name: The name of the security rule
# - priority: The priority of the rule, lower numbers have higher priority
# - direction: The direction of the traffic (Inbound or Outbound)
# - access: Whether the traffic is allowed or denied
# - protocol: The protocol to which the rule applies (e.g., Tcp)
# - source_port_range: The source port range
# - destination_port_range: The destination port range
# - source_address_prefix: The source address prefix
# - destination_address_prefix: The destination address prefix
resource "azurerm_network_security_group" "avd_nsg" {
  name                = "nsg-avd"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*" # Restrict to your IP in production!
    destination_address_prefix = "*"
  }
}

# This resource block associates an Azure Network Security Group (NSG) with Network Interfaces (NICs).
# This association ensures that the security rules defined in the NSG are applied to the specified NICs.
#
# The block creates associations for 2 NICs with the following configurations:
# - count: The number of NICs to associate with the NSG
# - network_interface_id: The ID of the network interface
# - network_security_group_id: The ID of the network security group
resource "azurerm_network_interface_security_group_association" "avd_nic_nsg" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.avd_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.avd_nsg.id
}