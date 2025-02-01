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
  for_each            = var.vm_names
  name                = "nic-${each.value}"
  location            = var.location2
  resource_group_name = azurerm_resource_group.rg-avd.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avd_subnet.id
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
  name                          = "kyvlt-avd-1"                                # Key Vault name
  location                      = var.location2                                # Location specified by the variable
  resource_group_name           = azurerm_resource_group.rg-avd.name           # Associated resource group
  tenant_id                     = data.azurerm_client_config.current.tenant_id # Tenant ID
  sku_name                      = "standard"                                   # SKU for the Key Vault
  purge_protection_enabled      = true                                         # Enable purge protection
  public_network_access_enabled = true                                         # $$$$$$enable public access

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
    // ip_rules can be specified if you wish to restrict to specific IP addresses
    // ip_rules = ["x.x.x.x/32", "y.y.y.y/32"]
  }
}



# This resource block assigns a role to a principal for accessing Azure Key Vault secrets.
# Role assignments are used to grant access to Azure resources by assigning roles to users, groups, or applications.

# Assign "Key Vault Secrets Officer" role to the Service Principal
resource "azurerm_role_assignment" "keyvault_secrets" {
  scope                = azurerm_key_vault.avd_kv.id                  # Scope of the role assignment (Key Vault ID)
  role_definition_name = "Key Vault Secrets Officer"                  # Role to be assigned
  principal_id         = data.azurerm_client_config.current.object_id # ID of the Service Principal

  depends_on = [azurerm_key_vault.avd_kv] # Ensure Key Vault is created first
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
  name            = "avd-admin-password"
  value           = var.admin_password
  key_vault_id    = azurerm_key_vault.avd_kv.id
  content_type    = "password"                    # Provides context for the secret
  expiration_date = timeadd(timestamp(), "8760h") # Expires in roughly 1 year

}
resource "azurerm_key_vault_secret" "admin_username" {
  name            = "avd-admin-username"
  value           = var.admin_username
  key_vault_id    = azurerm_key_vault.avd_kv.id
  content_type    = "username"                    # Provides context for the secret
  expiration_date = timeadd(timestamp(), "8760h") # Expires in roughly 1 year

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
  key_vault_id = azurerm_key_vault.avd_kv.id                  # ID of the Key Vault.
}


resource "azurerm_virtual_desktop_host_pool_registration_info" "avd_registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "24h"))
}


resource "azurerm_windows_virtual_machine" "avd_vm" {
  for_each              = var.vm_names
  name                  = each.value
  resource_group_name   = azurerm_resource_group.rg-avd.name
  location              = var.location2
  size                  = var.vm_size
  admin_username        = data.azurerm_key_vault_secret.admin_username.value
  admin_password        = data.azurerm_key_vault_secret.admin_password.value
  network_interface_ids = [azurerm_network_interface.avd_nic[each.key].id]

  encryption_at_host_enabled = true

  identity {
    type = "SystemAssigned"
  }

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

# Configure FSLogix profile location
New-Item -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VHDLocations" -Value "\\${azurerm_storage_account.fslogix_sa.name}.file.core.windows.net\\${azurerm_storage_share.fslogix_share.name}" -PropertyType String -Force
</powershell>
EOF
  )
}



# This resource block creates a private endpoint for an Azure Key Vault.
# A private endpoint allows secure access to Azure services over a private link, avoiding exposure to the public internet.

resource "azurerm_private_endpoint" "avd_kv_pe" {
  name                = "pe-kv-avd"                        # Name of the private endpoint
  location            = var.location2                      # Location specified by the 'location2' variable
  resource_group_name = azurerm_resource_group.rg-avd.name # Associated resource group
  subnet_id           = azurerm_subnet.avd_subnet.id       # ID of the subnet where the private endpoint will be created

  private_service_connection {
    name                           = "connection-kv-avd"         # Name of the private endpoint connection
    is_manual_connection           = false                       # Indicates if the connection is manually approved
    private_connection_resource_id = azurerm_key_vault.avd_kv.id # ID of the Azure Key Vault
    subresource_names              = ["vault"]                   # Subresource names for the private endpoint
  }
}




# This resource block creates an Azure Storage Account for FSLogix.
# An Azure Storage Account provides a scalable and secure storage solution for data objects, including blobs, files, queues, and tables.

resource "azurerm_storage_account" "fslogix_sa" {
  name                     = "fslogixavdint1"                   # Storage account name (must be globally unique)
  resource_group_name      = azurerm_resource_group.rg-avd.name # Associated resource group
  location                 = var.location2                      # Location specified by the 'location2' variable
  account_tier             = "Standard"                         # Performance tier (Standard or Premium)
  account_replication_type = "LRS"                              # Replication type (Locally-redundant storage)
  account_kind             = "StorageV2"                        # Storage account kind (StorageV2 for general-purpose v2)

}

# This resource block creates an Azure Storage Share for FSLogix.
# An Azure Storage Share is a file share in an Azure Storage Account, used to store and manage files.

resource "azurerm_storage_share" "fslogix_share" {
  name               = "fslogix"                             # Name of the storage share
  storage_account_id = azurerm_storage_account.fslogix_sa.id # ID of the associated storage account
  quota              = 1024                                  # Quota for the storage share in GB
}


# This resource block assigns a role to Azure Virtual Desktop (AVD) Virtual Machines (VMs) for accessing an FSLogix Storage Account.
# Role assignments are used to grant access to Azure resources by assigning roles to users, groups, or applications.

resource "azurerm_role_assignment" "fslogix_vm_role" {
  for_each = azurerm_windows_virtual_machine.avd_vm # Iterate over each AVD VM

  scope                = azurerm_storage_account.fslogix_sa.id     # Scope of the role assignment (ID of the FSLogix Storage Account)
  role_definition_name = "Storage File Data SMB Share Contributor" # Role to be assigned, allowing access to file shares
  principal_id         = each.value.identity[0].principal_id       # ID of the VM's managed identity

  depends_on = [
    azurerm_storage_account.fslogix_sa,    # Ensure the storage account is created first
    azurerm_windows_virtual_machine.avd_vm # Ensure the VMs are created first
  ]
}


# This block contains Azure CLI commands to register and show features for the Microsoft.Compute namespace.
# These commands are used to enable specific features in Azure, such as EncryptionAtHost, which provides encryption for data at rest on the host machine.

# Register the EncryptionAtHost feature in the Microsoft.Compute namespace
# az feature register --namespace Microsoft.Compute --name EncryptionAtHost

# Register the Microsoft.Compute namespace with Azure Resource Manager
# az provider register --namespace Microsoft.Compute

# Show the status of the EncryptionAtHost feature in the Microsoft.Compute namespace (duration +10 min)
# az feature show --namespace Microsoft.Compute --name EncryptionAtHost

# This resource block creates an Azure Log Analytics Workspace.
# A Log Analytics Workspace is used to collect and analyze log data from various Azure resources.


# This resource block creates an Azure Log Analytics Workspace.
# A Log Analytics Workspace is used to collect and analyze log data from various Azure resources.

# This resource block creates an Azure Log Analytics Workspace.
# A Log Analytics Workspace is used to collect and analyze log data from various Azure resources.

resource "azurerm_log_analytics_workspace" "avd_logs" {
  name                = "law-avd-logs"                     # Name of the Log Analytics Workspace
  location            = var.location2                      # Location specified by the 'location2' variable
  resource_group_name = azurerm_resource_group.rg-avd.name # Associated resource group
  sku                 = "PerGB2018"                        # Pricing tier for the workspace
  retention_in_days   = 30                                 # Number of days to retain log data
}

# This resource block creates diagnostic settings for Azure Virtual Desktop (AVD) Virtual Machines (VMs).
# Diagnostic settings are used to collect and send logs and metrics from Azure resources to different destinations, such as Log Analytics workspaces.

resource "azurerm_monitor_diagnostic_setting" "avd_vm_diag" {
  for_each = azurerm_windows_virtual_machine.avd_vm # Iterate over each AVD VM

  name                       = "diag-${each.key}"                          # Name of the diagnostic setting
  target_resource_id         = each.value.id                               # ID of the AVD VM
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_logs.id # ID of the Log Analytics workspace

  # Enable Metrics
  metric {
    category = "AllMetrics" # Category of metrics to collect
    enabled  = true         # Enable collection of metrics
  }

  depends_on = [azurerm_windows_virtual_machine.avd_vm] # Ensure VMs are created before applying diagnostic settings
}

# This resource block creates diagnostic settings for an FSLogix Storage Account.
# Diagnostic settings are used to collect and send logs from Azure resources to different destinations, such as Log Analytics workspaces.

resource "azurerm_monitor_diagnostic_setting" "fslogix_sa_diag" {
  name                       = "diag-fslogix-storage"
  target_resource_id         = azurerm_storage_account.fslogix_sa.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_logs.id

  metric {
    category = "Capacity"
    enabled  = true
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

# This resource block creates diagnostic settings for an Azure Virtual Desktop (AVD) Host Pool.
# Diagnostic settings are used to collect and send logs from Azure resources to different destinations, such as Log Analytics workspaces.

resource "azurerm_monitor_diagnostic_setting" "avd_hostpool_diag" {
  name                       = "diag-avd-hostpool"                                # Name of the diagnostic setting
  target_resource_id         = azurerm_virtual_desktop_host_pool.avd_host_pool.id # ID of the AVD Host Pool
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_logs.id        # ID of the Log Analytics workspace

  # Enable Checkpoint Logs
  enabled_log {
    category = "Checkpoint" # Category of logs to collect
  }

  # Enable Error Logs
  enabled_log {
    category = "Error" # Category of logs to collect
  }

  # Enable Management Logs
  enabled_log {
    category = "Management" # Category of logs to collect
  }

  # Enable Connection Logs
  enabled_log {
    category = "Connection" # Category of logs to collect
  }

  # Enable Host Registration Logs
  enabled_log {
    category = "HostRegistration" # Category of logs to collect
  }

  # Enable Agent Health Status Logs
  enabled_log {
    category = "AgentHealthStatus" # Category of logs to collect
  }

  # Enable Network Data Logs
  enabled_log {
    category = "NetworkData" # Category of logs to collect
  }

  # Enable Connection Graphics Data Logs
  enabled_log {
    category = "ConnectionGraphicsData" # Category of logs to collect
  }

  # Enable Session Host Management Logs
  enabled_log {
    category = "SessionHostManagement" # Category of logs to collect
  }

  # Enable Autoscale Evaluation Pooled Logs
  enabled_log {
    category = "AutoscaleEvaluationPooled" # Category of logs to collect
  }
}


# This resource block creates a CPU monitoring alert for Azure Virtual Desktop (AVD) Virtual Machines (VMs).
# Azure Monitor Metric Alerts are used to monitor the performance and health of Azure resources and trigger notifications or actions based on specified conditions.

resource "azurerm_monitor_metric_alert" "avd_cpu_alert" {
  name                = "avd-vm-high-cpu"
  resource_group_name = azurerm_resource_group.rg-avd.name
  scopes              = [for vm in azurerm_windows_virtual_machine.avd_vm : vm.id]
  description         = "Alert when average CPU usage on AVD VMs exceeds 80% for 5 minutes."
  severity            = 2
  window_size         = "PT5M"
  frequency           = "PT1M"

  target_resource_type     = "Microsoft.Compute/virtualMachines"
  target_resource_location = var.location2

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
}

