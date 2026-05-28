output "master_ip" {
  description = "IP publique du nœud master"
  value       = azurerm_public_ip.k8s_pip["master"].ip_address
}

output "worker1_ip" {
  description = "IP publique du nœud worker-1"
  value       = azurerm_public_ip.k8s_pip["worker-1"].ip_address
}

output "worker2_ip" {
  description = "IP publique du nœud worker-2"
  value       = azurerm_public_ip.k8s_pip["worker-2"].ip_address
}

output "hosts_entry" {
  description = "Lignes à ajouter dans /etc/hosts sur ton Mac"
  value       = <<-EOT
    ${azurerm_public_ip.k8s_pip["master"].ip_address} app.gestion-produits.local
    ${azurerm_public_ip.k8s_pip["master"].ip_address} dev.gestion-produits.local
  EOT
}

output "ssh_master" {
  description = "Commande SSH pour se connecter au master"
  value       = "ssh azureuser@${azurerm_public_ip.k8s_pip["master"].ip_address}"
}

output "kubeconfig_command" {
  description = "Commande pour récupérer le kubeconfig depuis le master"
  value       = "ssh azureuser@${azurerm_public_ip.k8s_pip["master"].ip_address} 'sudo microk8s config' > ~/.kube/config-azure"
}
