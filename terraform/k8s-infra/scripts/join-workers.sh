#!/bin/bash
# Exécuté sur TON MAC par Terraform (local-exec).
# 1. Se connecte au master pour générer un token "add-node"
# 2. Envoie ce token aux 2 workers pour qu'ils rejoignent le cluster
set -e

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_PRIVATE_KEY"

echo "=== Génération du token pour worker-1 ==="
JOIN_CMD_1=$(ssh $SSH_OPTS azureuser@$MASTER_IP \
  "sudo microk8s add-node --token-ttl 600 | grep 'microk8s join' | head -1")

echo "=== Worker-1 rejoint le cluster ==="
ssh $SSH_OPTS azureuser@$WORKER1_IP "sudo $JOIN_CMD_1"

echo "=== Génération du token pour worker-2 ==="
JOIN_CMD_2=$(ssh $SSH_OPTS azureuser@$MASTER_IP \
  "sudo microk8s add-node --token-ttl 600 | grep 'microk8s join' | head -1")

echo "=== Worker-2 rejoint le cluster ==="
ssh $SSH_OPTS azureuser@$WORKER2_IP "sudo $JOIN_CMD_2"

echo "=== Vérification du cluster depuis le master ==="
sleep 30
ssh $SSH_OPTS azureuser@$MASTER_IP "sudo microk8s kubectl get nodes"

echo "=== Cluster K8s constitué ! ==="
