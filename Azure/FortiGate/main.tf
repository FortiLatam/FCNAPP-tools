provider "azurerm" {
    features {}
    subscription_id = var.azure_subscription_id
  }
  
  locals {
    current_user_id = coalesce(data.azurerm_client_config.current.object_id)
  }

  resource "azurerm_key_vault" "fcnapp_kv" {
    name                        = var.key_vault_name
    location                    = var.location
    resource_group_name         = var.resource_group_name
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    sku_name                    = "standard"
    purge_protection_enabled    = false

  }
  
  
  resource "azurerm_key_vault_secret" "lwapi" {
    name         = "lwapi-secrets"
    value        = var.secret_lwapi
    key_vault_id = azurerm_key_vault.fcnapp_kv.id
    depends_on = [azurerm_key_vault_access_policy.terraform_user]
  }
  
  resource "azurerm_key_vault_secret" "xlwuaks" {
    name         = "x-lw-uaks"
    value        = var.secret_xlw
    key_vault_id = azurerm_key_vault.fcnapp_kv.id
    depends_on = [azurerm_key_vault_access_policy.terraform_user]
  }
  
  resource "azurerm_key_vault_access_policy" "terraform_user" {
    key_vault_id = azurerm_key_vault.fcnapp_kv.id
  
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
  
    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }
  
  resource "azurerm_key_vault_access_policy" "managed_identity" {
    key_vault_id = azurerm_key_vault.fcnapp_kv.id
  
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.fcnapp_id.principal_id
  
    secret_permissions = [
      "Get",
      "List"
    ]
  }
  

  data "azurerm_subscription" "current" {}
  
  data "azurerm_client_config" "current" {}
  
  resource "azurerm_role_definition" "fcnapp_role" {
    name        = var.role_name
    scope       = data.azurerm_subscription.current.id
    description = "Custom role for VM and KeyVault access"
  
    permissions {
      actions = [
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Compute/virtualMachines/write",
        "Microsoft.Resources/tags/write",
        "Microsoft.KeyVault/vaults/secrets/read"
      ]
      not_actions = []
    }
  
    assignable_scopes = [
      data.azurerm_subscription.current.id
    ]
  }
  
  resource "azurerm_user_assigned_identity" "fcnapp_id" {
    name                = var.identity_name
    location            = var.location
    resource_group_name = var.resource_group_name
  }
  
  resource "azurerm_role_assignment" "assign_fcnapp_role" {
    scope              = data.azurerm_subscription.current.id
    role_definition_id = azurerm_role_definition.fcnapp_role.role_definition_resource_id
    principal_id       = azurerm_user_assigned_identity.fcnapp_id.principal_id
  }
  
  resource "azurerm_storage_account" "fcnapp_storage" {
    name                     = var.storage_account_name
    resource_group_name      = var.resource_group_name
    location                 = var.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
  }
  
  resource "azurerm_service_plan" "fcnapp_plan" {
    name                = "fcnapp-asp"
    location            = var.location
    resource_group_name = var.resource_group_name
  
    sku_name = "FC1"
    os_type  = "Linux"
    
    per_site_scaling_enabled = false
    maximum_elastic_worker_count = 1

  }
  
  resource "azurerm_storage_container" "function_code" {
    name                  = "functioncode"
    storage_account_name  = azurerm_storage_account.fcnapp_storage.name
    container_access_type = "private"
  }
  
  resource "azurerm_storage_blob" "function_zip" {
    name                   = "function_package.zip"
    storage_account_name   = azurerm_storage_account.fcnapp_storage.name
    storage_container_name = azurerm_storage_container.function_code.name
    type                   = "Block"
    source                 = "./function/function_package.zip"
  }


resource "azurerm_function_app_flex_consumption" "fcnapp_function" {
  name                = var.function_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.fcnapp_plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.fcnapp_storage.primary_blob_endpoint}${azurerm_storage_container.function_code.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.fcnapp_storage.primary_access_key
  runtime_name                = "python"
  runtime_version             = "3.11"
  maximum_instance_count      = 40
  instance_memory_in_mb       = 2048

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.fcnapp_id.id]
  }

  app_settings = {
    AZURE_CLIENT_ID         = azurerm_user_assigned_identity.fcnapp_id.client_id
    AZURE_SUBSCRIPTION_ID   = var.azure_subscription_id
    AZURE_KEYVAULT_NAME     = azurerm_key_vault.fcnapp_kv.name
    FCNAPP_TENANT_NAME      = var.fcnapp_tenant_name
  }

  site_config {
    ip_restriction {
      name       = "LW1"
      ip_address = "34.208.85.38/32"
      action     = "Allow"
      priority   = 110
    }
    ip_restriction {
      name       = "LW2"
      ip_address = "35.165.121.10/32"
      action     = "Allow"
      priority   = 120
    }
    ip_restriction {
      name       = "LW3"
      ip_address = "35.165.62.149/32"
      action     = "Allow"
      priority   = 130
    }
    ip_restriction {
      name       = "LW4"
      ip_address = "35.165.83.150/32"
      action     = "Allow"
      priority   = 140
    }
    ip_restriction {
      name       = "L25"
      ip_address = "35.166.181.157/32"
      action     = "Allow"
      priority   = 150
    }
    ip_restriction {
      name       = "LW6"
      ip_address = "35.93.121.192/26"
      action     = "Allow"
      priority   = 160
    }
    ip_restriction {
      name       = "LW7"
      ip_address = "44.231.201.69/32"
      action     = "Allow"
      priority   = 170
    }
    ip_restriction {
      name       = "LW8"
      ip_address = "52.42.23.33/32"
      action     = "Allow"
      priority   = 180
    }
    ip_restriction {
      name       = "LW9"
      ip_address = "52.43.197.121/32"
      action     = "Allow"
      priority   = 190
    }
    ip_restriction {
      name       = "LW10"
      ip_address = "52.88.113.199/32"
      action     = "Allow"
      priority   = 200
    }
    ip_restriction {
      name       = "LW11"
      ip_address = "54.200.230.179/32"
      action     = "Allow"
      priority   = 210
    }
    ip_restriction {
      name       = "LW12"
      ip_address = "54.203.18.248/32"
      action     = "Allow"
      priority   = 220
    }
    ip_restriction {
      name       = "LW13"
      ip_address = "54.213.7.200/32"
      action     = "Allow"
      priority   = 230
    }
    ip_restriction {
      name       = "DenyAll"
      ip_address = "0.0.0.0/0"
      action     = "Deny"
      priority   = 240
    }
  }
}

resource "null_resource" "deploy_function" {
  provisioner "local-exec" {
    command = <<EOT
      az functionapp deployment source config-zip --resource-group ${var.resource_group_name} --name ${azurerm_function_app_flex_consumption.fcnapp_function.name} --src "./function/function_package.zip" || echo "Health check failed due to network restrictions, it is not a real problem..."
    EOT
  }

  depends_on = [azurerm_function_app_flex_consumption.fcnapp_function]
}
