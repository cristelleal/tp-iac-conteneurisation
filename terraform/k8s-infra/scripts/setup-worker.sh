#!/bin/bash
# Exécuté sur chaque VM worker par Terraform (remote-exec).
# Installe MicroK8s mais ne rejoint pas encore le cluster.
# La jonction se fait par le script join-workers.sh (local-exec).
set -e

echo "=== Installation de MicroK8s ==="
sudo snap install microk8s --classic --channel=1.28/stable

sudo usermod -aG microk8s azureuser

echo "=== Attente que MicroK8s soit prêt ==="
sudo microk8s status --wait-ready --timeout 120

echo "=== Worker prêt (en attente de rejoindre le cluster) ==="
