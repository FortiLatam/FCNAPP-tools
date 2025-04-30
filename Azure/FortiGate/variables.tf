variable "resource_group_name" {
  type        = string
  description = "Nome do resource group"
}

variable "location" {
  type        = string
  description = "Região dos recursos"
}

variable "key_vault_name" {
  type        = string
  description = "Nome do Key Vault"
}

variable "secret_lwapi" {
  type        = string
  description = "Valor do segredo lwapi-secrets"
}

variable "secret_xlw" {
  type        = string
  description = "Valor do segredo x-lw-uaks"
}

variable "role_name" {
  type        = string
  description = "Nome da role customizada"
}

variable "identity_name" {
  type        = string
  description = "Nome da Managed Identity"
}

variable "function_app_name" {
  type        = string
  description = "Nome da Function App"
}

variable "ip_allow_list" {
  type        = list(string)
  description = "Lista de IPs permitidos"
}

variable "azure_subscription_id" {
  type        = string
  description = "ID da assinatura Azure"
}

variable "tag_name" {
  type        = string
  description = "Nome da variável de ambiente"
}