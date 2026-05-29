#!/bin/bash
# Exécuté sur la VM master par Terraform (remote-exec).
# Installe MicroK8s et active les add-ons essentiels.
set -e

echo "=== Attente de snapd ==="
sudo snap wait system seed.loaded

echo "=== Installation de MicroK8s ==="
sudo snap install microk8s --classic --channel=1.28/stable

# Ajouter l'utilisateur au groupe microk8s pour éviter sudo
sudo usermod -aG microk8s azureuser
mkdir -p /home/azureuser/.kube
sudo chown -R azureuser /home/azureuser/.kube

echo "=== Attente que MicroK8s soit prêt ==="
sudo microk8s status --wait-ready --timeout 300

echo "=== Activation des add-ons ==="
# dns    : résolution de noms entre pods
# ingress: Nginx Ingress Controller (ports 80/443)
# storage: stockage persistant (PersistentVolumeClaims)
sudo microk8s enable dns ingress storage

echo "=== Vérification ==="
sudo microk8s kubectl get nodes
sudo microk8s kubectl get pods -A

echo "=== Master prêt ==="
