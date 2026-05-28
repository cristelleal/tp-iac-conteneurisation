# Valeurs affichées à la fin de "terraform apply"

output "docker_host_ip" {
  description = "IP publique de la VM Docker — à ajouter dans /etc/hosts"
  value       = azurerm_public_ip.docker_pip.ip_address
}

output "ssh_command" {
  description = "Commande pour se connecter à la VM via SSH"
  value       = "ssh azureuser@${azurerm_public_ip.docker_pip.ip_address}"
}

output "hosts_entry" {
  description = "Lignes à ajouter dans /etc/hosts sur ton Mac"
  value       = <<-EOT
    ${azurerm_public_ip.docker_pip.ip_address} app.gestion-produits.local
    ${azurerm_public_ip.docker_pip.ip_address} dev.gestion-produits.local
  EOT
}
