#!/bin/bash
# Génère un certificat TLS auto-signé pour l'environnement local (Docker)
# À lancer une fois avant "docker compose up"
set -e

CERT_DIR="docker/nginx/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/gestion-produits.key" \
  -out    "$CERT_DIR/gestion-produits.crt" \
  -subj "/CN=gestion-produits.local" \
  -addext "subjectAltName=DNS:app.gestion-produits.local,DNS:dev.gestion-produits.local"

echo "Certificats générés dans $CERT_DIR/"
echo "Vous pouvez maintenant lancer : docker compose up -d"
