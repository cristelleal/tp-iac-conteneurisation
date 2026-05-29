# Architecture — TP IaC Conteneurisation

## Vue d'ensemble

Ce projet déploie une application PHP de gestion de produits sur trois environnements :

| Environnement | Infrastructure | Déclenchement |
|---|---|---|
| **Local** | Docker Compose sur le poste de développement | `docker compose up` |
| **Cloud — Docker** | 1 VM Azure + Docker Compose | `terraform apply` (docker-infra) |
| **Cloud — Kubernetes** | 3 VMs Azure + cluster MicroK8s 3 nœuds | `terraform apply` (k8s-infra) |

---

## 1. Application PHP

CRUD de gestion de produits en PHP 8.2 + Apache.

L'application supporte deux moteurs de base de données via la variable d'environnement `DB_TYPE` :

| `DB_TYPE` | Base de données | Environnement |
|-----------|-----------------|---------------|
| `mysql`   | MySQL 8.0       | prod          |
| `pgsql`   | PostgreSQL 15   | dev           |

### Adaptations pour la compatibilité MySQL / PostgreSQL

L'application d'origine était MySQL-only. Trois fichiers ont été modifiés :

| Fichier | Problème d'origine | Solution |
|---------|-------------------|----------|
| `php/www/connect.php` | Credentials en dur, driver MySQL fixe | Connexion via variables d'environnement, bascule PDO mysql/pgsql selon `DB_TYPE` |
| `php/www/auth.php` | Utilise `SHA2()`, fonction MySQL uniquement | Hash calculé côté PHP avec `hash('sha256', ...)` |
| `php/www/validation.php` | `lastInsertId()` sans argument | Appel `lastInsertId('table_id_seq')` pour PostgreSQL (requiert le nom de la séquence) |

---

## 2. Conteneurisation Docker

### Image (`docker/Dockerfile`)

Base : `php:8.2-apache`

```
php:8.2-apache
  ├── extensions : pdo, pdo_mysql, pdo_pgsql
  ├── Apache mod_rewrite activé
  ├── code PHP (php/www/)
  └── entrypoint.sh (copie les images de démo au premier démarrage)
```

L'image est construite pour `linux/amd64` (nécessaire sur Mac Apple Silicon pour garantir la compatibilité avec les VMs Azure x86).

### Stack locale — Docker Compose

5 conteneurs sur le poste de développement :

```
Port 80 (hôte)
      │
      ▼
┌─────────────────────────────────────────────────┐
│  nginx:1.25-alpine  (reverse proxy)             │
│  app.gestion-produits.local  → php-prod:80      │
│  dev.gestion-produits.local  → php-dev:80       │
└────────────────┬─────────────────┬──────────────┘
                 │                 │
       ┌─────────▼────────┐ ┌──────▼──────────┐
       │    php-prod      │ │    php-dev       │
       │  DB_TYPE=mysql   │ │  DB_TYPE=pgsql   │
       └─────────┬────────┘ └──────┬───────────┘
                 │                 │
       ┌─────────▼────────┐ ┌──────▼───────────┐
       │   db-prod        │ │   db-dev          │
       │   MySQL 8.0      │ │   PostgreSQL 15   │
       └──────────────────┘ └───────────────────┘
```

Volumes nommés pour la persistance : `mysql_data`, `postgres_data`, `uploads_prod`, `uploads_dev`.

---

## 3. Infrastructure Docker sur Azure (Terraform)

### Pourquoi 8 ressources pour 1 seule VM ?

Sur Azure, une VM ne peut pas exister de façon autonome. Elle a besoin d'un ensemble de ressources réseau. Terraform les crée toutes explicitement :

```
Azure
└── Resource Group  (1)  — conteneur logique obligatoire
    ├── Virtual Network  (2)  — réseau privé 10.0.0.0/16
    │   └── Subnet  (3)  — sous-réseau 10.0.1.0/24
    ├── Network Security Group  (4)  — pare-feu : ports 22, 80, 443
    ├── Public IP  (5)  — adresse IP publique fixe (Static)
    ├── Network Interface  (6)  — carte réseau virtuelle
    ├── NIC ↔ NSG Association  (7)  — branche le pare-feu sur la NIC
    └── Linux Virtual Machine  (8)  — Ubuntu 22.04, Standard_B2s
```

### Rôle de chaque ressource Terraform

| # | Ressource | Rôle |
|---|-----------|------|
| 1 | `azurerm_resource_group` | Conteneur obligatoire. Toutes les ressources d'un projet y sont regroupées. |
| 2 | `azurerm_virtual_network` | Réseau privé isolé. Plage `10.0.0.0/16` (65 534 adresses). |
| 3 | `azurerm_subnet` | Découpe du VNet. Ici un seul sous-réseau : `10.0.1.0/24`. |
| 4 | `azurerm_network_security_group` | Pare-feu inbound : autorise SSH (22), HTTP (80), HTTPS (443). Tout le reste est bloqué. |
| 5 | `azurerm_public_ip` | IP publique statique — ne change pas au redémarrage de la VM. |
| 6 | `azurerm_network_interface` | Relie la VM au subnet et à l'IP publique. |
| 7 | `azurerm_network_interface_security_group_association` | Sans cette ressource, le NSG est créé mais n'est pas appliqué à la NIC. |
| 8 | `azurerm_linux_virtual_machine` | VM Ubuntu 22.04 LTS, Standard_B2s (2 vCPU, 4 GB RAM). |

### Flux de déploiement Terraform — infra Docker

```
terraform apply
    │
    ├── 1. Création des 8 ressources Azure réseau + VM
    │
    ├── 2. Provisioner "file" (copie sur la VM via SSH) :
    │       docker-compose.prod.yml  →  /home/azureuser/docker-compose.yml
    │       docker/nginx/nginx.conf  →  /home/azureuser/nginx/
    │       database/*.sql           →  /home/azureuser/database/
    │
    └── 3. Provisioner "remote-exec" — scripts/setup-docker.sh :
            apt install docker-ce docker-compose-plugin
            docker compose pull    ← tire l'image depuis Docker Hub
            docker compose up -d   ← lance nginx + mysql + postgres + php×2
```

---

## 4. Cluster Kubernetes sur Azure (Terraform)

### Architecture réseau 3 nœuds

```
Internet
    │  port 80/443
    ▼
┌─────────────────────────────────────────────┐
│  k8s-master  Standard_D2s_v3 (2 vCPU, 8 GB)│
│  IP publique unique du cluster              │
│  MicroK8s : dns + ingress + storage         │
│  Nginx Ingress Controller                   │
└──────────────┬─────────────────┬────────────┘
               │ VNet 10.1.1.0/24│ (IP privées seulement)
      ┌────────▼──────┐  ┌───────▼──────────┐
      │  k8s-worker-1 │  │  k8s-worker-2    │
      │ D2as_v4       │  │ D2as_v4          │
      │ 2 vCPU, 8 GB  │  │ 2 vCPU, 8 GB     │
      └───────────────┘  └──────────────────┘
```

**Pourquoi deux familles de VM différentes ?**

Les quotas Azure Étudiant s'appliquent par famille de VM. Utiliser deux familles (`standardDSv3` pour le master, `standardDASv4` pour les workers) répartit la consommation sur deux enveloppes distinctes, tout en restant sous le quota total de 6 cœurs.

### Ressources Terraform du cluster (14 au total)

```
Azure
└── Resource Group
    ├── Virtual Network  10.1.0.0/16
    │   └── Subnet  10.1.1.0/24  (partagé entre les 3 nœuds)
    ├── Network Security Group  (1 NSG pour les 3 VMs)
    │   ├── Règle SSH          port 22   (toutes sources)
    │   ├── Règle HTTP         port 80   (toutes sources)
    │   ├── Règle HTTPS        port 443  (toutes sources)
    │   ├── Règle MicroK8s-API port 16443 (VNet interne uniquement)
    │   ├── Règle MicroK8s-Cluster port 25000 (VNet interne uniquement)
    │   └── Règle Internal     tout port (VNet interne uniquement)
    ├── Public IP  (master uniquement — les workers n'ont pas d'IP publique)
    ├── NIC master  (IP publique + IP privée)
    ├── NIC worker-1  (IP privée uniquement)
    ├── NIC worker-2  (IP privée uniquement)
    ├── NIC ↔ NSG associations  (×3)
    ├── VM k8s-master
    ├── VM k8s-worker-1
    ├── VM k8s-worker-2
    └── null_resource join_workers
```

### Flux de déploiement Terraform — infra K8s

```
terraform apply
    │
    ├── 1. Création des ressources réseau Azure
    │
    ├── 2. remote-exec sur k8s-master  →  setup-master.sh :
    │       snap wait system seed.loaded   ← attend que snapd soit prêt
    │       snap install microk8s --classic --channel=1.28/stable
    │       microk8s status --wait-ready
    │       microk8s enable dns ingress storage
    │
    ├── 3. remote-exec sur worker-1 et worker-2  →  setup-worker.sh :
    │       (connexion SSH via le master comme bastion — les workers n'ont pas d'IP publique)
    │       snap install microk8s --classic --channel=1.28/stable
    │       microk8s status --wait-ready
    │       (le worker est prêt mais pas encore joint au cluster)
    │
    └── 4. local-exec sur le Mac  →  join-workers.sh :
            Pour chaque worker :
              ssh master → microk8s add-node --token-ttl 600
              ssh worker (via ProxyCommand → master) → microk8s join <token>
            ssh master → microk8s kubectl get nodes  (vérification)
```

**Détail du `join-workers.sh` :**

Les workers n'ayant pas d'IP publique, la connexion SSH depuis le Mac passe par le master comme jump host. Le script utilise `ProxyCommand` plutôt que `-J` car les placeholders SSH `%h:%p` ne se transmettent pas correctement à travers une variable shell avec `-J`.

```bash
ssh_worker() {
  local target_ip="$1"; shift
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_PRIVATE_KEY \
    -o "ProxyCommand=ssh -o StrictHostKeyChecking=no ... -W %h:%p azureuser@$MASTER_IP" \
    azureuser@"$target_ip" "$@"
}
```

### Namespaces Kubernetes déployés

```
Cluster MicroK8s
│
├── namespace: prod
│   ├── Secret           db-secret           — credentials base de données (base64)
│   ├── PVC              mysql-pvc (5 Gi)    — données MySQL persistantes
│   ├── PVC              uploads-pvc (2 Gi)  — images produits persistantes
│   ├── ConfigMap        mysql-configmap     — script SQL d'initialisation
│   ├── Deployment       mysql               — MySQL 8.0
│   ├── Service          db (ClusterIP)      — accès interne à MySQL
│   ├── Deployment       php-app             — PHP prod (DB_TYPE=mysql)
│   ├── Service          php-service (ClusterIP)
│   └── Ingress          → app.gestion-produits.local
│
└── namespace: dev
    ├── Secret           db-secret
    ├── PVC              postgres-pvc (5 Gi)
    ├── PVC              uploads-pvc (2 Gi)
    ├── ConfigMap        postgres-configmap
    ├── Deployment       postgres            — PostgreSQL 15
    ├── Service          db (ClusterIP)
    ├── Deployment       php-app             — PHP dev (DB_TYPE=pgsql)
    ├── Service          php-service (ClusterIP)
    └── Ingress          → dev.gestion-produits.local
```

### Rôle de chaque objet Kubernetes

| Objet | Rôle |
|-------|------|
| **Namespace** | Isolation logique — les ressources prod et dev ne se voient pas, sauf via les Services exposés. |
| **Secret** | Stocke les credentials encodés en base64. Monté en variables d'environnement dans les pods. |
| **PVC** (PersistentVolumeClaim) | Demande de stockage persistant. Les données survivent au redémarrage ou remplacement d'un pod. Satisfait par le `storage` add-on de MicroK8s (hostpath). |
| **ConfigMap** | Fichier de configuration injecté dans les conteneurs. Ici : script SQL exécuté à l'initialisation de la base. |
| **Deployment** | Déclare un ou plusieurs pods à maintenir en vie, avec leur image, variables d'environnement et volumes. |
| **Service ClusterIP** | Point d'accès réseau stable et interne au cluster vers un Deployment. L'adresse IP du pod peut changer ; le Service, non. |
| **Ingress** | Règles de routage HTTP(S) à l'entrée du cluster : tel nom de domaine → tel Service. Géré par le Nginx Ingress Controller intégré à MicroK8s. |

---

## 5. Sécurité réseau

### NSG docker-infra

| Règle | Port | Source | Direction |
|-------|------|--------|-----------|
| SSH | 22 | Toute source | Inbound |
| HTTP | 80 | Toute source | Inbound |
| HTTPS | 443 | Toute source | Inbound |

### NSG k8s-infra

| Règle | Port | Source | Direction | Raison |
|-------|------|--------|-----------|--------|
| SSH | 22 | Toute source | Inbound | Administration |
| HTTP | 80 | Toute source | Inbound | Application web |
| HTTPS | 443 | Toute source | Inbound | Application web HTTPS |
| MicroK8s-API | 16443 | VNet interne | Inbound | API Kubernetes (add-node, kubectl) |
| MicroK8s-Cluster | 25000 | VNet interne | Inbound | Agent de cluster (join) |
| Internal | tous ports | VNet interne | Inbound | Communication inter-nœuds (kubelet, Calico, etcd) |

Les ports MicroK8s (16443, 25000) et le trafic interne ne sont accessibles que depuis l'intérieur du VNet (`10.1.0.0/16`), jamais depuis internet.

---

## 6. Résumé des URLs

| URL | Environnement | Base de données | Infrastructure |
|-----|---------------|-----------------|----------------|
| `http://app.gestion-produits.local` | prod | MySQL 8.0 | Docker Compose local, docker-infra, k8s-infra |
| `http://dev.gestion-produits.local` | dev | PostgreSQL 15 | Docker Compose local, docker-infra, k8s-infra |

Identifiants par défaut : `admin` / `password`

---

## 7. Outputs Terraform utiles

### docker-infra

| Output | Valeur |
|--------|--------|
| `public_ip` | IP publique de la VM Docker |
| `hosts_entry` | Lignes prêtes à coller dans `/etc/hosts` |
| `ssh_command` | Commande SSH pour se connecter à la VM |

### k8s-infra

| Output | Valeur |
|--------|--------|
| `master_ip` | IP publique du nœud master |
| `worker1_private_ip` | IP privée du worker-1 |
| `worker2_private_ip` | IP privée du worker-2 |
| `ssh_master` | `ssh azureuser@<master_ip>` |
| `ssh_worker1` | `ssh -J azureuser@<master_ip> azureuser@<worker1_ip>` |
| `ssh_worker2` | `ssh -J azureuser@<master_ip> azureuser@<worker2_ip>` |
| `hosts_entry` | Lignes à ajouter dans `/etc/hosts` |
| `kubeconfig_command` | Commande pour récupérer le kubeconfig depuis le master |
