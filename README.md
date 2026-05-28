# TP IaC – Conteneurisation avancée — M1 DEV EPSI

Application de gestion de produits déployée sur Docker et Kubernetes (MicroK8s) via Terraform sur Azure.

---

## Architecture

```
Azure (Azure for Students)
├── VM docker-host  (Standard_B2s)  → Docker + Nginx reverse proxy
├── VM k8s-master   (Standard_B2s)  ┐
├── VM k8s-worker-1 (Standard_B2s)  ├─ Cluster MicroK8s 3 nœuds
└── VM k8s-worker-2 (Standard_B2s)  ┘
```

**URLs :**
- `http://app.gestion-produits.local` → version prod (MySQL)
- `http://dev.gestion-produits.local` → version dev (PostgreSQL)

---

## Structure du projet

```
├── php/www/                    Application PHP (modifiée pour MySQL + PostgreSQL)
├── database/
│   ├── gestion_produits.sql    Schéma MySQL (prod)
│   └── gestion_produits_pg.sql Schéma PostgreSQL (dev)
├── docker/
│   ├── Dockerfile              Image PHP 8.2 Apache + pdo_mysql + pdo_pgsql
│   ├── entrypoint.sh           Initialisation des images de démo au démarrage
│   └── nginx/nginx.conf        Reverse proxy (2 virtual hosts)
├── docker-compose.yml          Stack complète locale (prod + dev)
├── terraform/
│   ├── docker-infra/           Terraform : VM Azure + Docker
│   └── k8s-infra/              Terraform : 3 VMs Azure + MicroK8s
├── kubernetes/
│   ├── prod/                   Manifests K8s prod (MySQL)
│   └── dev/                    Manifests K8s dev (PostgreSQL)
└── scripts/
    ├── build-push.sh           Build et push de l'image sur Docker Hub
    └── deploy-k8s.sh           Déploiement sur le cluster
```

---

## Prérequis

```bash
brew install azure-cli terraform kubectl
az login
```

Clé SSH (si inexistante) :
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

## Étape 1 — Test local avec Docker Compose

```bash
# Copier le fichier d'environnement
cp .env.example .env

# Lancer toute la stack (prod MySQL + dev PostgreSQL + Nginx)
docker compose up --build -d

# Ajouter les domaines locaux dans /etc/hosts
echo "127.0.0.1 app.gestion-produits.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 dev.gestion-produits.local" | sudo tee -a /etc/hosts
```

- http://app.gestion-produits.local → version MySQL
- http://dev.gestion-produits.local → version PostgreSQL
- Identifiants : `admin` / `password`

Arrêter :
```bash
docker compose down
```

---

## Étape 2 — Build et push de l'image Docker

```bash
# Se connecter à Docker Hub
docker login

# Build et push (remplacer VOTRE_USERNAME)
chmod +x scripts/build-push.sh
./scripts/build-push.sh VOTRE_USERNAME
```

> L'option `--platform linux/amd64` est nécessaire si tu es sur Mac Apple Silicon (ARM).

---

## Étape 3 — Infrastructure Docker sur Azure (Terraform)

```bash
cd terraform/docker-infra

# Copier et remplir les variables
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars : remplacer VOTRE_USERNAME par ton username Docker Hub

# Initialiser Terraform (télécharge le provider Azure)
terraform init

# Voir ce que Terraform va créer (sans rien toucher)
terraform plan

# Créer l'infrastructure et déployer l'application
terraform apply

# Affiche l'IP publique et les lignes à ajouter dans /etc/hosts
terraform output
```

Mettre à jour `/etc/hosts` avec l'IP affichée :
```bash
echo "IP_AFFICHEE app.gestion-produits.local" | sudo tee -a /etc/hosts
echo "IP_AFFICHEE dev.gestion-produits.local" | sudo tee -a /etc/hosts
```

Détruire l'infrastructure (stopper les coûts) :
```bash
terraform destroy
```

---

## Étape 4 — Cluster Kubernetes MicroK8s sur Azure (Terraform)

```bash
cd terraform/k8s-infra

cp terraform.tfvars.example terraform.tfvars

# Rendre les scripts exécutables
chmod +x scripts/*.sh

terraform init
terraform plan
terraform apply
```

Terraform crée 3 VMs, installe MicroK8s et constitue le cluster automatiquement.

Récupérer le kubeconfig :
```bash
# IP affichée par "terraform output ssh_master"
ssh azureuser@IP_MASTER 'sudo microk8s config' > ~/.kube/config-azure
export KUBECONFIG=~/.kube/config-azure

# Vérifier le cluster
kubectl get nodes
```

Résultat attendu :
```
NAME           STATUS   ROLES    AGE
k8s-master     Ready    <none>   5m
k8s-worker-1   Ready    <none>   3m
k8s-worker-2   Ready    <none>   3m
```

---

## Étape 5 — Déploiement de l'application sur K8s

```bash
chmod +x scripts/deploy-k8s.sh

# Déploie prod (MySQL) + dev (PostgreSQL) en une commande
./scripts/deploy-k8s.sh VOTRE_USERNAME
```

Mettre à jour `/etc/hosts` avec l'IP du master :
```bash
echo "IP_MASTER app.gestion-produits.local" | sudo tee -a /etc/hosts
echo "IP_MASTER dev.gestion-produits.local" | sudo tee -a /etc/hosts
```

Vérifier :
```bash
kubectl get pods,ingress -n prod
kubectl get pods,ingress -n dev
```

---

## Modifications PHP

| Fichier | Modification | Raison |
|---------|-------------|--------|
| `connect.php` | Connexion via variables d'environnement | Compatible MySQL ET PostgreSQL |
| `auth.php` | SHA256 calculé côté PHP au lieu de `SHA2()` SQL | `SHA2()` est une fonction MySQL-only |
| `validation.php` | `lastInsertId()` adapté pour PostgreSQL | PostgreSQL requiert le nom de la séquence |

---

## Choix techniques

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| Conteneurisation | PHP 8.2 Apache | Image officielle, stable, facile à configurer |
| Reverse proxy Docker | Nginx | Léger, performant, virtual hosts simples |
| IaC | Terraform + Azure provider | Standard industrie, free tier étudiant |
| Cloud | Azure for Students | $100 crédits, aucune CB requise |
| Distribution K8s | MicroK8s | Canonical officiel, installation snap, add-ons intégrés |
| Stockage K8s | MicroK8s storage add-on | Suffisant pour démo, zéro configuration |
| Ingress K8s | MicroK8s ingress add-on (Nginx) | Intégré, activé en une commande |
