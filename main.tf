# This Terraform deployment deploys Foundry Virtual Tabletop in an Azure Webapp
# This deployment will ensure persitence and prevent secrets to leak

# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.17.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# First, create the resources container
resource "azurerm_resource_group" "rg" {
  name     = var.base_name
  location = var.location
}

########################################
#             Secret store             #
########################################

# Create a keyvault to store all sensitive info
resource "azurerm_key_vault" "keyvault" {
  name                = "${azurerm_resource_group.rg.name}-kv"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  timeouts {
    create = "60m"
  }
}

# Allows the foundry webapp to access the Keyvault to retrieve secrets
resource "azurerm_key_vault_access_policy" "keyvault_creator_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  key_permissions = [
    "Backup",
    "Create",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Get",
    "Import",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "Update",
    "Verify",
    "WrapKey"
  ]

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Set"
  ]

  storage_permissions = [
    "Backup",
    "Delete",
    "DeleteSAS",
    "Get",
    "GetSAS",
    "List",
    "ListSAS",
    "Purge",
    "Recover",
    "RegenerateKey",
    "Restore",
    "Set",
    "SetSAS",
    "Update"
  ]
  certificate_permissions = [
    "Backup",
    "Create",
    "DeleteIssuers",
    "Get",
    "GetIssuers",
    "Import",
    "Delete",
    "List",
    "ListIssuers",
    "ManageContacts",
    "ManageIssuers",
    "Purge",
    "Recover",
    "Restore",
    "SetIssuers",
    "Update"
  ]
}


# In this keyvault, we store foundry site login...
resource "azurerm_key_vault_secret" "foundry_username" {
  name         = "foundry-username"
  value        = var.foundry_username
  key_vault_id = azurerm_key_vault.keyvault.id
  lifecycle {
    ignore_changes = [value, version]
  }
}

# Password ...
resource "azurerm_key_vault_secret" "foundry_password" {
  name         = "foundry-password"
  value        = var.foundry_password
  key_vault_id = azurerm_key_vault.keyvault.id
  lifecycle {
    ignore_changes = [value, version]
  }
}

# The planned external hostname ...
resource "azurerm_key_vault_secret" "foundry_hostname" {
  name         = "foundry-hostname"
  value        = var.foundry_hostname
  key_vault_id = azurerm_key_vault.keyvault.id
  lifecycle {
    ignore_changes = [value, version]
  }
}

# And finally the admin panel password ...
resource "azurerm_key_vault_secret" "foundry_admin_password" {
  name         = "foundry-admin-password"
  value        = var.foundry_admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
  lifecycle {
    ignore_changes = [value, version]
  }
}


########################################
#          Persitence layer            #
########################################

# Next, we need to persists data, such as world and config, to be sure to
# not lose anything if the app restarts
# The chosen backend service for this will be a Storage Account
resource "azurerm_storage_account" "st" {
  name                     = format("%sst", replace(replace(azurerm_resource_group.rg.name, " ", ""), "-", ""))
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# On the storage account, create a new file share later to be shared with the app
resource "azurerm_storage_share" "st-share" {
  name                 = "foundry-data"
  storage_account_name = azurerm_storage_account.st.name

  quota = 5120
  depends_on = [
    azurerm_storage_account.st
  ]
}


########################################
#          Application layer           #
########################################

# Create the backing VM for the Webapp
resource "azurerm_service_plan" "webapp-plan" {
  name                = "${azurerm_resource_group.rg.name}-app-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

# Create a log receiver
resource "azurerm_application_insights" "ai" {
  name                = "${azurerm_resource_group.rg.name}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}


# And finally create the webapp itself
resource "azurerm_linux_web_app" "foundry" {
  name                = "${azurerm_resource_group.rg.name}-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.webapp-plan.location
  service_plan_id     = azurerm_service_plan.webapp-plan.id

  site_config {
    application_stack {
      docker_image     = "felddy/foundryvtt"
      docker_image_tag = "release"

    }

  }

  logs {
    application_logs {
      file_system_level = "Verbose"
    }
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }


  identity {
    type = "SystemAssigned"
  }

  # Env
  app_settings = {
    # Retrieve any sensitive info for the keyvault 
    "FOUNDRY_USERNAME"                    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.foundry_username.versionless_id})"
    "FOUNDRY_PASSWORD"                    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.foundry_password.versionless_id})"
    "FOUNDRY_HOSTNAME"                    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.foundry_hostname.versionless_id})"
    "FOUNDRY_LOCAL_HOSTNAME"              = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.foundry_hostname.versionless_id})"
    "FOUNDRY_ADMIN_KEY"                   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.foundry_admin_password.versionless_id})"
    "FOUNDRY_MINIFY_STATIC_FILES"         = "true"
    "TIMEZONE"                            = "FR"
    "WEBSITES_PORT"                       = 30000
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = "${azurerm_application_insights.ai.instrumentation_key}"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://index.docker.io/v1"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = false
  }

  # Bind the fileshare created earlier to the path "/data" in the container 
  storage_account {
    name         = azurerm_storage_account.st.name
    type         = "AzureFiles"
    share_name   = azurerm_storage_share.st-share.name
    account_name = azurerm_storage_account.st.name
    access_key   = azurerm_storage_account.st.primary_access_key
    mount_path   = "/data"
  }
}

# Allows the foundry webapp to access the Keyvault to retrieve secrets
resource "azurerm_key_vault_access_policy" "keyvault_app_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.foundry.identity[0].principal_id
  secret_permissions = [
    "Get"
  ]
}
