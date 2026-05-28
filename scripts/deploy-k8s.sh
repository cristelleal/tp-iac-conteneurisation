#!/bin/bash
# Déploie l'application sur le cluster MicroK8s
# Prérequis : KUBECONFIG pointant vers le cluster (export KUBECONFIG=~/.kube/config-azure)

set -e

echo "=== Déploiement namespace PROD (MySQL) ==="
kubectl apply -f kubernetes/prod/

echo "=== Déploiement namespace DEV (PostgreSQL) ==="
kubectl apply -f kubernetes/dev/

echo "=== Attente que les pods soient prêts ==="
kubectl rollout status deployment/php-app -n prod --timeout=120s
kubectl rollout status deployment/php-app -n dev  --timeout=120s

echo "=== État du cluster ==="
kubectl get pods,svc,ingress -n prod
kubectl get pods,svc,ingress -n dev

echo ""
echo "Ajouter dans /etc/hosts avec l'IP du master :"
echo "  IP_MASTER  app.gestion-produits.local"
echo "  IP_MASTER  dev.gestion-produits.local"
