output "master_ip" {
  description = "IP publique du nœud master"
  value       = azurerm_public_ip.k8s_master_pip.ip_address
}

output "worker1_private_ip" {
  description = "IP privée du nœud worker-1"
  value       = azurerm_network_interface.k8s_worker_nic["worker-1"].private_ip_address
}

output "worker2_private_ip" {
  description = "IP privée du nœud worker-2"
  value       = azurerm_network_interface.k8s_worker_nic["worker-2"].private_ip_address
}

output "hosts_entry" {
  description = "Lignes à ajouter dans /etc/hosts sur ton Mac"
  value       = <<-EOT
    ${azurerm_public_ip.k8s_master_pip.ip_address} app.gestion-produits.local
    ${azurerm_public_ip.k8s_master_pip.ip_address} dev.gestion-produits.local
  EOT
}

output "ssh_master" {
  description = "Commande SSH pour se connecter au master"
  value       = "ssh azureuser@${azurerm_public_ip.k8s_master_pip.ip_address}"
}

output "ssh_worker1" {
  description = "Commande SSH pour se connecter au worker-1 via le master"
  value       = "ssh -J azureuser@${azurerm_public_ip.k8s_master_pip.ip_address} azureuser@${azurerm_network_interface.k8s_worker_nic["worker-1"].private_ip_address}"
}

output "ssh_worker2" {
  description = "Commande SSH pour se connecter au worker-2 via le master"
  value       = "ssh -J azureuser@${azurerm_public_ip.k8s_master_pip.ip_address} azureuser@${azurerm_network_interface.k8s_worker_nic["worker-2"].private_ip_address}"
}

output "kubeconfig_command" {
  description = "Commande pour récupérer le kubeconfig depuis le master"
  value       = "ssh azureuser@${azurerm_public_ip.k8s_master_pip.ip_address} 'sudo microk8s config' > ~/.kube/config-azure"
}
