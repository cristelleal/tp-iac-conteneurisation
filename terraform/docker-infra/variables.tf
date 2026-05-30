# Variables du module Terraform pour l'infrastructure Docker

variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  type        = string
  default     = "rg-gestion-produits-docker"
}

variable "location" {
  description = "Région Azure (ex: francecentral, westeurope)"
  type        = string
  default     = "francecentral"
}

variable "vm_size" {
  description = "Taille de la VM Azure (Standard_D2s_v3 = 2 vCPU, 8 GB RAM)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé SSH publique (~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé SSH privée (~/.ssh/id_rsa)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "subscription_id" {
  description = "ID de la subscription Azure (az account show --query id)"
  type        = string
}

