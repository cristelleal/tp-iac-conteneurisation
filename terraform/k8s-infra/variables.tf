variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure pour le cluster K8s"
  type        = string
  default     = "rg-gestion-produits-k8s"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "vm_size" {
  description = "Taille des VMs (Standard_B2s = 2 vCPU, 4 GB RAM)"
  type        = string
  default     = "Standard_B2s"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé SSH privée"
  type        = string
  default     = "~/.ssh/id_rsa"
}
