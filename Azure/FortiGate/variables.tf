variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Resource region"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name"
}

variable "secret_lwapi" {
  type        = string
  description = "secret for lwapi-secrets"
}

variable "secret_xlw" {
  type        = string
  description = "secre for x-lw-uaks"
}

variable "role_name" {
  type        = string
  description = "Custom role name"
}

variable "identity_name" {
  type        = string
  description = "Managed Identity name"
}

variable "function_app_name" {
  type        = string
  description = "Function App name"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription id"
}

variable "tag_name" {
  type        = string
  description = "Tag Name"
}

variable "fcnapp_tenant_name" {
  type        = string
  description = "Your FortiCNAPP demo. Example: partner-demo if your URL is https://partner-demo.lacework.net/"
}

variable "storage_account_name" {
  type        = string
  description = "Name for Storage Account"
}