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

resource "azurerm_virtual_network" "avd_vnet" {
  name                = "vnet-avd-int-westeu"              # Name of the VNet
  location            = var.location2                      # Location specified by the 'location2' variable
  resource_group_name = azurerm_resource_group.rg-avd.name # Associated resource group
  address_space       = ["10.0.0.0/16"]                    # Address space for the VNet
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

# This resource block creates a Network Security Group (NSG) for Azure Virtual Desktop (AVD).
# An NSG is used to control inbound and outbound traffic to network interfaces (NICs), VMs, and subnets.

resource "azurerm_network_security_group" "avd_nsg" {
  name                = "nsg-avd"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name

  # Allow RDP Access (Modify source_address_prefix for security)
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_rdp_ips # Using the variable here
    destination_address_prefix = "*"
  }

  # Allow AVD Management Traffic (Required for AVD functionality)
  security_rule {
    name                       = "Allow-AVD-Management"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "9350", "9354"]  # Required for AVD service
    source_address_prefix      = "AzureFrontDoor.Backend" # Microsoft-recommended AVD service tag
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic (Implicitly denied, but explicitly adding it for clarity)
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
# This resource block associates a Network Security Group (NSG) with a Subnet.
# Associating an NSG with a subnet applies the security rules to all resources within the subnet.

resource "azurerm_subnet_network_security_group_association" "avd_subnet_nsg" {
  subnet_id                 = azurerm_subnet.avd_subnet.id
  network_security_group_id = azurerm_network_security_group.avd_nsg.id
}



# This resource block creates an Azure Key Vault.
# Azure Key Vault is a service that provides secure storage and management of sensitive information such as secrets, keys, and certificates.
data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "avd_kv" {
  name                = "kyvlt-avd-1"                                # Name of the Key Vault
  location            = var.location2                                # Location specified by the 'location2' variable
  resource_group_name = azurerm_resource_group.rg-avd.name           # Associated resource group
  tenant_id           = data.azurerm_client_config.current.tenant_id # Tenant ID for the Key Vault
  sku_name            = "standard"                                   # SKU for the Key Vault
}

# This resource block assigns a role to a principal for accessing Azure Key Vault secrets.
# Role assignments are used to grant access to Azure resources by assigning roles to users, groups, or applications.

# Assign "Key Vault Secrets Officer" role to the Service Principal
resource "azurerm_role_assignment" "keyvault_secrets" {
  scope                = azurerm_key_vault.avd_kv.id  # Scope of the role assignment (Key Vault ID)
  role_definition_name = "Key Vault Secrets Officer"  # Role to be assigned
  principal_id         = data.azurerm_client_config.current.object_id  # ID of the Service Principal

  depends_on = [azurerm_key_vault.avd_kv]  # Ensure Key Vault is created first
}

# This resource block creates an access policy for Azure Key Vault.
# An access policy defines the permissions for a user, group, or application to access secrets, keys, and certificates in the Key Vault.

# Define access policy for the Service Principal
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.avd_kv.id                  # ID of the Key Vault
  tenant_id    = data.azurerm_client_config.current.tenant_id # Tenant ID
  object_id    = data.azurerm_client_config.current.object_id # Service Principal ID

  # Permissions for secrets
  secret_permissions = [
    "Get",    # Permission to retrieve secrets
    "Set",    # Permission to create or update secrets
    "Delete", # Permission to delete secrets
    "List"    # Permission to list secrets
  ]
}
# This resource block stores a secret in Azure Key Vault.
# Azure Key Vault Secret is used to securely store and manage sensitive information such as passwords, tokens, and API keys.

# Store Admin Password and username in Key Vault
resource "azurerm_key_vault_secret" "admin_password" {
  name         = "avd-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.avd_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform] # ✅ Ensure policy is applied first
}

resource "azurerm_key_vault_secret" "admin_username" {
  name         = "avd-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.avd_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform] # ✅ Ensure policy is applied first
}

# This data block retrieves a secret from Azure Key Vault.
# Azure Key Vault Secret is used to securely store and manage sensitive information such as passwords, tokens, and API keys.

# Retrieve Admin Password from Key Vault
data "azurerm_key_vault_secret" "admin_password" {
  name         = azurerm_key_vault_secret.admin_password.name # Name of the secret
  key_vault_id = azurerm_key_vault.avd_kv.id                  # ID of the Key Vault
}
# This data block retrieves a secret from Azure Key Vault.
# Azure Key Vault Secret is used to securely store and manage sensitive information such as passwords, tokens, and API keys.

# Retrieve Admin Username from Key Vault
data "azurerm_key_vault_secret" "admin_username" {
  name         = azurerm_key_vault_secret.admin_username.name # Name of the secret
  key_vault_id = azurerm_key_vault.avd_kv.id                  # ID of the Key Vault
}


resource "azurerm_virtual_desktop_host_pool_registration_info" "avd_registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "24h"))
}


resource "azurerm_windows_virtual_machine" "avd_vm" {
  count               = var.vm_count
  name                = "avd-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg-avd.name
  location            = var.location2
  size                = var.vm_size
  admin_username      = data.azurerm_key_vault_secret.admin_username.value
  admin_password      = data.azurerm_key_vault_secret.admin_password.value

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

  # Ensure the host pool registration is created before VMs
  depends_on = [azurerm_virtual_desktop_host_pool_registration_info.avd_registration]

  custom_data = base64encode(<<EOF
<powershell>
# Install AVD Agent
Invoke-WebRequest -Uri "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv" -OutFile "C:\avdagent.msi"
Start-Process "msiexec.exe" -ArgumentList "/i C:\avdagent.msi /quiet /norestart" -Wait

# Register VM with Host Pool
$token = "${azurerm_virtual_desktop_host_pool_registration_info.avd_registration.token}"
$cmd = "C:\Program Files\Microsoft RDInfra\Agent\RDAgentBootLoader.exe /token:$token"
Start-Process -FilePath "powershell" -ArgumentList "-Command $cmd" -NoNewWindow -Wait
</powershell>
EOF
  )
}
