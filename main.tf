# This Terraform deployment deploys Foundry Virtual Tabletop in an Azure Webapp
# This deployment will ensure persitence and prevent secrets to leak

# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.109.0"
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

#######################################
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
  access_tier              = "Cool"
  account_replication_type = "LRS"
}

# On the storage account, create a new file share later to be shared with the app
resource "azurerm_storage_share" "st_share" {
  name                 = "foundry-data"
  storage_account_name = azurerm_storage_account.st.name
  access_tier          = "Cool"
  quota                = 5
  depends_on = [
    azurerm_storage_account.st
  ]
}


########################################
#          Application layer           #
########################################


# Logs store
resource "azurerm_log_analytics_workspace" "analytics" {
  name                = "${azurerm_resource_group.rg.name}-la"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  # Pay per GB of logs. Great in any case.
  sku               = "PerGB2018"
  retention_in_days = 30
}

# Create a Container App Env (https://learn.microsoft.com/en-us/azure/container-apps/environment) env to host our apps
resource "azurerm_container_app_environment" "env" {
  name                       = "${azurerm_resource_group.rg.name}-aca-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.analytics.id
  workload_profile {
    name = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# Bind the created file share to the container apps environment
resource "azurerm_container_app_environment_storage" "foundry_data" {
  name                         = "foundry-data"
  container_app_environment_id = azurerm_container_app_environment.env.id
  account_name                 = azurerm_storage_account.st.name
  share_name                   = azurerm_storage_share.st_share.name
  access_key                   = azurerm_storage_account.st.primary_access_key
  access_mode                  = "ReadWrite"
}

# Create the "send" app in the environment 
resource "azurerm_container_app" "foundry" {
  name                         = "foundry"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  # We'll store foundy credentials as secrets
  secret {
    name  = "foundry-pass"
    value = var.foundry_password
  }
  secret {
    name  = "foundry-user"
    value = var.foundry_username
  }
  secret {
    name  = "foundry-host"
    value = var.foundry_hostname
  }
  secret {
    name  = "foundry-admin-pass"
    value = var.foundry_admin_password
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    # To persist world data, we mount the SMB share
    volume {
      name         = "data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.foundry_data.name
    }

    container {
      name   = "foundry"
      image  = "felddy/foundryvtt:${var.foundry_tag}"
      cpu    = var.cpu_per_replica
      memory = var.ram_per_replica
      env {
        name        = "FOUNDRY_USERNAME"
        secret_name = "foundry-user"
      }
      env {
        name        = "FOUNDRY_PASSWORD"
        secret_name = "foundry-pass"
      }
      env {
        name        = "FOUNDRY_HOSTNAME"
        secret_name = "foundry-host"
      }
      env {
        name        = "FOUNDRY_LOCAL_HOSTNAME"
        secret_name = "foundry-host"
      }
      env {
        name        = "FOUNDRY_ADMIN_KEY"
        secret_name = "foundry-admin-pass"
      }
      env {
        name  = "FOUNDRY_MINIFY_STATIC_FILES"
        value = "true"
      }
      # This allows to solve a "OPERATION NOT PERMITTED" bug
      # when foundry tries to update the config.
      # As the config files aren't persisted in between session
      # we can just tell the container to ignore them 
      env {
        name  = "CONTAINER_PRESERVE_CONFIG"
        value = "true"
      }
      env {
        name  = "CONTAINER_PRESERVE_OWNER"
        value = "/data"
      }
      env {
        name  = "TIMEZONE"
        value = "FR"
      }

      # We do not save logs and config as config is regenerated at each startup and logs are handled
      # by the log analytics workspace
      volume_mounts {
        name = "data"
        path = "/data"
      }
    }

  }

  identity {
    type = "SystemAssigned"
  }

  # Expose send 
  ingress {
    external_enabled = true
    target_port      = 30000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

}
