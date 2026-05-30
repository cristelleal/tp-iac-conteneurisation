#!/bin/bash
# Script exécuté automatiquement par Terraform sur la VM Azure après sa création.
# Installe Docker, puis lance l'application en tirant l'image depuis Docker Hub.
set -e

echo "=== Mise à jour des paquets ==="
sudo apt-get update -y

echo "=== Installation de Docker ==="
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker azureuser

echo "=== Préparation des fichiers de l'application ==="
mkdir -p /home/azureuser/app/docker/nginx/certs
mkdir -p /home/azureuser/app/database

# Les fichiers ont été copiés par le provisioner "file" de Terraform
cp /home/azureuser/docker-compose.yml /home/azureuser/app/
cp -r /home/azureuser/nginx/* /home/azureuser/app/docker/nginx/
cp -r /home/azureuser/database/* /home/azureuser/app/database/

echo "=== Génération du certificat TLS auto-signé ==="
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /home/azureuser/app/docker/nginx/certs/gestion-produits.key \
  -out    /home/azureuser/app/docker/nginx/certs/gestion-produits.crt \
  -subj "/CN=gestion-produits.local" \
  -addext "subjectAltName=DNS:app.gestion-produits.local,DNS:dev.gestion-produits.local"

echo "=== Lancement de l'application (pull depuis Docker Hub) ==="
cd /home/azureuser/app

# Tire les images depuis Docker Hub (pas de build local)
sudo docker compose pull

# Lance tous les conteneurs en arrière-plan
sudo docker compose up -d

echo "=== Installation terminée ==="
sudo docker compose ps
