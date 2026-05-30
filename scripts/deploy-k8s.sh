#!/bin/bash
# Déploie l'application sur le cluster MicroK8s
# Prérequis : KUBECONFIG pointant vers le cluster (export KUBECONFIG=~/.kube/config-azure)

set -e

echo "=== Génération du certificat TLS auto-signé ==="
CERT_DIR="$(mktemp -d)"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/tls.key" \
  -out    "$CERT_DIR/tls.crt" \
  -subj "/CN=gestion-produits.local" \
  -addext "subjectAltName=DNS:app.gestion-produits.local,DNS:dev.gestion-produits.local"

echo "=== Déploiement namespace PROD (MySQL) ==="
kubectl apply -f kubernetes/prod/
kubectl create secret tls tls-secret -n prod \
  --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Déploiement namespace DEV (PostgreSQL) ==="
kubectl apply -f kubernetes/dev/
kubectl create secret tls tls-secret -n dev \
  --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

rm -rf "$CERT_DIR"

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
echo ""
echo "Accès HTTPS (certificat auto-signé) :"
echo "  https://app.gestion-produits.local"
echo "  https://dev.gestion-produits.local"
