#!/bin/bash
# Exécuté sur TON MAC par Terraform (local-exec).
# Les workers n'ont pas d'IP publique : on passe par le master (jump host).
# 1. Génère un token "add-node" sur le master
# 2. SSH vers chaque worker via le master pour exécuter la jonction
set -e

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_PRIVATE_KEY"

ssh_worker() {
  local target_ip="$1"
  shift
  ssh $SSH_OPTS \
    -o "ProxyCommand=ssh $SSH_OPTS -W %h:%p azureuser@$MASTER_IP" \
    azureuser@"$target_ip" "$@"
}

echo "=== Génération du token pour worker-1 ==="
JOIN_CMD_1=$(ssh $SSH_OPTS azureuser@$MASTER_IP \
  "sudo microk8s add-node --token-ttl 600 | grep 'microk8s join' | head -1")

echo "=== Worker-1 rejoint le cluster (via jump host master) ==="
ssh_worker "$WORKER1_IP" "sudo $JOIN_CMD_1"

echo "=== Génération du token pour worker-2 ==="
JOIN_CMD_2=$(ssh $SSH_OPTS azureuser@$MASTER_IP \
  "sudo microk8s add-node --token-ttl 600 | grep 'microk8s join' | head -1")

echo "=== Worker-2 rejoint le cluster (via jump host master) ==="
ssh_worker "$WORKER2_IP" "sudo $JOIN_CMD_2"

echo "=== Vérification du cluster depuis le master ==="
sleep 30
ssh $SSH_OPTS azureuser@$MASTER_IP "sudo microk8s kubectl get nodes"

echo "=== Cluster K8s constitué ! ==="
