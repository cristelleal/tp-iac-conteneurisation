#!/bin/bash
# Exécuté sur chaque VM worker par Terraform (remote-exec).
# Installe MicroK8s mais ne rejoint pas encore le cluster.
# La jonction se fait par le script join-workers.sh (local-exec).
set -e

echo "=== Attente de snapd ==="
sudo snap wait system seed.loaded

echo "=== Installation des dépendances ==="
sudo apt-get update -y
sudo apt-get install -y nfs-common

echo "=== Installation de MicroK8s ==="
sudo snap install microk8s --classic --channel=1.28/stable

sudo usermod -aG microk8s azureuser

echo "=== Attente que MicroK8s soit prêt ==="
sudo microk8s status --wait-ready --timeout 300

echo "=== Worker prêt (en attente de rejoindre le cluster) ==="
