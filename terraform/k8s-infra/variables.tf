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
  description = "Taille de la VM master (Standard_D2s_v3 = 2 vCPU, 8 GB RAM)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "worker_vm_size" {
  description = "Taille des VMs workers — famille différente pour éviter les limites de quota Azure par famille (Standard_D2as_v4 = 2 vCPU, 8 GB RAM)"
  type        = string
  default     = "Standard_D2as_v4"
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
