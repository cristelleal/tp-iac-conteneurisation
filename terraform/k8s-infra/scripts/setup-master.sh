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

echo "=== Installation du serveur NFS ==="
sudo apt-get install -y nfs-kernel-server
sudo mkdir -p /srv/nfs/k8s/{mysql,postgres,uploads-prod,uploads-dev}
sudo chmod -R 777 /srv/nfs/k8s
cat << 'EOF' | sudo tee /etc/exports
/srv/nfs/k8s/mysql         10.1.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/k8s/postgres      10.1.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/k8s/uploads-prod  10.1.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/k8s/uploads-dev   10.1.0.0/16(rw,sync,no_subtree_check,no_root_squash)
EOF
sudo exportfs -a
sudo systemctl enable nfs-kernel-server
sudo systemctl start nfs-kernel-server

echo "=== Activation des add-ons ==="
# dns    : résolution de noms entre pods
# ingress: Nginx Ingress Controller (ports 80/443)
sudo microk8s enable dns ingress

echo "=== Vérification ==="
sudo microk8s kubectl get nodes
sudo microk8s kubectl get pods -A

echo "=== Master prêt ==="
