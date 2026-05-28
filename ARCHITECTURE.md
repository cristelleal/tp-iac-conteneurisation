# Architecture — TP IaC Conteneurisation

## Vue d'ensemble

Ce projet déploie une application PHP de gestion de produits sur deux environnements :

- **Local** : Docker Compose sur ta machine
- **Cloud** : Azure, via Terraform, en deux configurations :
  - Une VM avec Docker + Nginx (infra Docker)
  - Un cluster Kubernetes 3 nœuds avec MicroK8s (infra K8s)

---

## 1. Application PHP

L'application est un CRUD de gestion de produits (PHP 8.2 + Apache).

Elle supporte deux bases de données selon l'environnement :

| Variable `DB_TYPE` | Base de données | Environnement |
|--------------------|-----------------|---------------|
| `mysql`            | MySQL 8.0       | prod          |
| `pgsql`            | PostgreSQL 15   | dev           |

### Fichiers modifiés pour la compatibilité MySQL / PostgreSQL

| Fichier | Modification |
|---------|-------------|
| `php/www/connect.php` | Connexion via variables d'environnement, bascule PDO mysql/pgsql selon `DB_TYPE` |
| `php/www/auth.php` | Hash SHA256 calculé en PHP (la fonction `SHA2()` est MySQL uniquement) |
| `php/www/validation.php` | `lastInsertId()` avec nom de séquence pour PostgreSQL |

---

## 2. Conteneurisation Docker

### Image Docker (`docker/Dockerfile`)

Basée sur `php:8.2-apache`. Elle installe les extensions PDO pour MySQL et PostgreSQL, active le module Apache `rewrite`, et copie le code PHP.

```
php:8.2-apache
  └── pdo + pdo_mysql + pdo_pgsql
  └── apache mod_rewrite
  └── code PHP (php/www/)
  └── entrypoint.sh (copie les images de démo au premier démarrage)
```

### Stack locale — Docker Compose

Lance 5 conteneurs sur ton Mac :

```
Port 80
   │
   ▼
┌─────────────────────────────────────────────┐
│  nginx (reverse proxy)                       │
│  app.gestion-produits.local → php-prod:80   │
│  dev.gestion-produits.local → php-dev:80    │
└───────────────┬─────────────────┬───────────┘
                │                 │
        ┌───────▼───────┐ ┌───────▼───────┐
        │   php-prod    │ │   php-dev     │
        │ DB_TYPE=mysql │ │ DB_TYPE=pgsql │
        └───────┬───────┘ └───────┬───────┘
                │                 │
        ┌───────▼───────┐ ┌───────▼───────┐
        │  db-prod      │ │  db-dev       │
        │  MySQL 8.0    │ │  PostgreSQL15 │
        └───────────────┘ └───────────────┘
```

---

## 3. Infrastructure Docker sur Azure (Terraform)

### Pourquoi 8 ressources pour une seule VM ?

Sur Azure, une machine virtuelle ne peut pas exister seule. Elle a besoin de tout un réseau autour d'elle. Terraform crée chaque composant explicitement :

```
Azure
└── Resource Group  (1)  — conteneur logique qui regroupe tout
    ├── Virtual Network  (2)  — réseau privé virtuel (10.0.0.0/16)
    │   └── Subnet  (3)  — sous-réseau de la VM (10.0.1.0/24)
    ├── Network Security Group  (4)  — pare-feu : ports 22, 80, 443
    ├── Public IP  (5)  — adresse IP publique fixe (Static)
    ├── Network Interface  (6)  — carte réseau virtuelle de la VM
    ├── NIC ↔ NSG Association  (7)  — branche le pare-feu sur la carte réseau
    └── Linux Virtual Machine  (8)  — la VM Ubuntu 22.04 (Standard_B2s)
```

### Détail de chaque ressource

| # | Ressource Terraform | Rôle |
|---|---------------------|------|
| 1 | `azurerm_resource_group` | Conteneur obligatoire sur Azure. Toutes les ressources d'un projet doivent être dans un groupe. |
| 2 | `azurerm_virtual_network` | Le réseau privé de la VM. Personne d'autre ne peut y accéder directement. Plage d'adresses : `10.0.0.0/16` (65 000 adresses). |
| 3 | `azurerm_subnet` | Découpe du VNet en sous-réseaux. Ici un seul : `10.0.1.0/24` (256 adresses). |
| 4 | `azurerm_network_security_group` | Le pare-feu. Définit les règles d'entrée (inbound) : SSH port 22, HTTP port 80, HTTPS port 443. Tout le reste est bloqué. |
| 5 | `azurerm_public_ip` | L'IP publique visible depuis internet. En mode `Static` : elle ne change pas si la VM redémarre. |
| 6 | `azurerm_network_interface` | La carte réseau virtuelle. Relie la VM au subnet et à l'IP publique. |
| 7 | `azurerm_network_interface_security_group_association` | Attache le pare-feu (NSG) à la carte réseau. Sans ça, les règles du NSG ne s'appliquent pas. |
| 8 | `azurerm_linux_virtual_machine` | La VM elle-même. Ubuntu 22.04 LTS, taille Standard_B2s (2 vCPU, 4 GB RAM). Terraform s'y connecte en SSH pour installer Docker et démarrer les conteneurs. |

### Flux de déploiement Terraform (infra Docker)

```
terraform apply
    │
    ├── 1. Crée les 8 ressources Azure
    │
    ├── 2. Provisioner "file" — copie sur la VM :
    │       docker-compose.prod.yml → /home/azureuser/docker-compose.yml
    │       docker/nginx/nginx.conf → /home/azureuser/nginx/
    │       database/*.sql         → /home/azureuser/database/
    │
    └── 3. Provisioner "remote-exec" — exécute setup-docker.sh :
            apt install docker-ce docker-compose-plugin
            docker compose pull   (tire l'image depuis Docker Hub)
            docker compose up -d  (lance nginx + mysql + postgres + php×2)
```

---

## 4. Cluster Kubernetes sur Azure (Terraform)

### Architecture 3 nœuds MicroK8s

```
Internet
    │  port 80
    ▼
┌──────────────────────────────────────────┐
│  k8s-master  (Standard_B2s)              │
│  MicroK8s + dns + ingress + storage      │
│  Ingress Controller (Nginx)              │
└────────┬──────────────┬──────────────────┘
         │              │
   ┌─────▼──────┐ ┌─────▼──────┐
   │ k8s-worker-1│ │k8s-worker-2│
   │ Standard_B2s│ │Standard_B2s│
   └─────────────┘ └────────────┘
```

Terraform crée 3 VMs, installe MicroK8s sur chacune, puis les joint automatiquement en cluster via `microk8s add-node` / `microk8s join`.

### Namespaces Kubernetes

```
Cluster MicroK8s
├── namespace: prod
│   ├── Secret (db-secret)           — mot de passe base de données
│   ├── PVC mysql-pvc (5Gi)          — données MySQL persistantes
│   ├── PVC uploads-pvc (2Gi)        — images produits persistantes
│   ├── ConfigMap mysql-configmap    — script SQL d'initialisation
│   ├── Deployment mysql             — MySQL 8.0
│   ├── Service db (ClusterIP)       — accès interne MySQL
│   ├── Deployment php-app           — PHP prod (DB_TYPE=mysql)
│   ├── Service php-service (ClusterIP)
│   └── Ingress → app.gestion-produits.local
│
└── namespace: dev
    ├── Secret (db-secret)
    ├── PVC postgres-pvc (5Gi)
    ├── PVC uploads-pvc (2Gi)
    ├── ConfigMap postgres-configmap
    ├── Deployment postgres           — PostgreSQL 15
    ├── Service db (ClusterIP)
    ├── Deployment php-app            — PHP dev (DB_TYPE=pgsql)
    ├── Service php-service (ClusterIP)
    └── Ingress → dev.gestion-produits.local
```

### Ce qu'est chaque objet Kubernetes

| Objet | Rôle |
|-------|------|
| **Namespace** | Isolation logique — prod et dev ne se voient pas |
| **Secret** | Stocke les mots de passe encodés en base64 |
| **PVC** (PersistentVolumeClaim) | Demande de stockage persistant. Les données survivent au redémarrage des pods. |
| **ConfigMap** | Fichier de configuration injecté dans les conteneurs (ici : script SQL d'init) |
| **Deployment** | Déclare un conteneur à faire tourner, avec son image et ses variables d'environnement |
| **Service** | Point d'accès réseau stable vers un Deployment. `ClusterIP` = interne au cluster uniquement. |
| **Ingress** | Règles HTTP d'entrée : quel nom de domaine → quel Service. Géré par le Nginx intégré à MicroK8s. |

---

## 5. Résumé des URLs

| URL | Environnement | Base de données |
|-----|---------------|-----------------|
| `http://app.gestion-produits.local` | prod | MySQL 8.0 |
| `http://dev.gestion-produits.local` | dev | PostgreSQL 15 |

Identifiants : `admin` / `password`

---

## 6. Choix techniques

| Composant | Technologie | Raison |
|-----------|-------------|--------|
| Application | PHP 8.2 + Apache | Existant dans le TP |
| Image Docker | `php:8.2-apache` | Image officielle, stable |
| Reverse proxy | Nginx | Léger, virtual hosts simples |
| IaC | Terraform + Azure provider | Standard industrie |
| Cloud | Azure for Students | 100$ de crédits, sans CB |
| VM | Standard_B2s (2 vCPU, 4 GB) | Rapport prix/perf suffisant pour une démo |
| Distribution K8s | MicroK8s (Canonical) | Installation en une commande via snap, add-ons intégrés (dns, ingress, storage) |
| Stockage K8s | MicroK8s storage add-on | Zéro configuration pour une démo |
| Ingress K8s | MicroK8s ingress add-on | Nginx intégré, activé en une commande |
