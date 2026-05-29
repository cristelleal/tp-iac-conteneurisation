#!/bin/bash
# Build l'image Docker et la pousse sur Docker Hub
# Usage : ./scripts/build-push.sh <docker-username>
# Exemple : ./scripts/build-push.sh cristellea

set -e

DOCKER_USER=${1:?"Usage: $0 <docker-username>"}
IMAGE="$DOCKER_USER/gestion-produits:latest"

echo "=== Build de l'image Docker ==="
docker build \
  --platform linux/amd64 \
  -t "$IMAGE" \
  -f docker/Dockerfile \
  .

echo "=== Push vers Docker Hub ==="
docker push "$IMAGE"

echo "=== Image disponible : $IMAGE ==="
