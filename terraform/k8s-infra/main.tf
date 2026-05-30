# ─────────────────────────────────────────────────────────────────
# TERRAFORM — Cluster Kubernetes MicroK8s sur Azure (3 nœuds)
#
# Ce fichier crée :
#   - 1 groupe de ressources Azure
#   - 1 VNet + sous-réseau partagé entre les 3 nœuds
#   - 1 NSG : ports SSH, HTTP, HTTPS + ports internes MicroK8s
#   - 3 IPs publiques + 3 interfaces réseau
#   - 3 VMs Ubuntu 22.04 (k8s-master, k8s-worker-1, k8s-worker-2)
#   - Installation automatique de MicroK8s sur chaque nœud
# ─────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─── GROUPE DE RESSOURCES ───────────────────────────────────────
resource "azurerm_resource_group" "k8s_rg" {
  name     = var.resource_group_name
  location = var.location
}

# ─── RÉSEAU VIRTUEL PARTAGÉ ─────────────────────────────────────
# Les 3 nœuds communiquent sur ce réseau interne
resource "azurerm_virtual_network" "k8s_vnet" {
  name                = "k8s-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
}

resource "azurerm_subnet" "k8s_subnet" {
  name                 = "k8s-subnet"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# ─── PARE-FEU ───────────────────────────────────────────────────
resource "azurerm_network_security_group" "k8s_nsg" {
  name                = "k8s-nsg"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Port API MicroK8s — utilisé pour joindre des nœuds au cluster
  security_rule {
    name                       = "MicroK8s-API"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "16443"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  # Port agent de cluster MicroK8s (add-node)
  security_rule {
    name                       = "MicroK8s-Cluster"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "25000"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  # Trafic interne entre nœuds (kubelet, etcd, etc.)
  security_rule {
    name                       = "Internal"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
}

# ─── IP PUBLIQUE (master uniquement) ────────────────────────────
# Les workers n'ont pas d'IP publique : ils communiquent via le VNet
# interne et sont joints au cluster via le master (jump host SSH).
resource "azurerm_public_ip" "k8s_master_pip" {
  name                = "k8s-master-pip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─── INTERFACES RÉSEAU ──────────────────────────────────────────
# Master : IP publique + IP privée
resource "azurerm_network_interface" "k8s_master_nic" {
  name                = "k8s-master-nic"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.10"
    public_ip_address_id          = azurerm_public_ip.k8s_master_pip.id
  }
}

# Workers : IP privée uniquement
resource "azurerm_network_interface" "k8s_worker_nic" {
  for_each = toset(["worker-1", "worker-2"])

  name                = "k8s-${each.key}-nic"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "k8s_master_nsg" {
  network_interface_id      = azurerm_network_interface.k8s_master_nic.id
  network_security_group_id = azurerm_network_security_group.k8s_nsg.id
}

resource "azurerm_network_interface_security_group_association" "k8s_worker_nsg" {
  for_each = toset(["worker-1", "worker-2"])

  network_interface_id      = azurerm_network_interface.k8s_worker_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.k8s_nsg.id
}

# ─── VM MASTER ──────────────────────────────────────────────────
# Nœud maître : gère le cluster, héberge l'API K8s
resource "azurerm_linux_virtual_machine" "k8s_master" {
  name                = "k8s-master"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  size                = var.vm_size
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.k8s_master_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip_address
    user        = "azureuser"
    private_key = file(var.ssh_private_key_path)
  }

  # Installe MicroK8s et active les add-ons nécessaires
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup-master.sh"
  }
}

# ─── VMs WORKERS ────────────────────────────────────────────────
# Nœuds de travail : exécutent les conteneurs applicatifs
resource "azurerm_linux_virtual_machine" "k8s_workers" {
  for_each = toset(["worker-1", "worker-2"])

  name                = "k8s-${each.key}"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  size                = var.worker_vm_size
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.k8s_worker_nic[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Les workers n'ont pas d'IP publique : connexion SSH via le master
  connection {
    type         = "ssh"
    host         = azurerm_network_interface.k8s_worker_nic[each.key].private_ip_address
    user         = "azureuser"
    private_key  = file(var.ssh_private_key_path)
    bastion_host = azurerm_public_ip.k8s_master_pip.ip_address
    bastion_user = "azureuser"
  }

  # Installe MicroK8s sur le worker (sans encore rejoindre le cluster)
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup-worker.sh"
  }
}

# ─── JONCTION DES WORKERS AU CLUSTER ────────────────────────────
# S'exécute APRÈS la création des 3 VMs.
# Ce null_resource tourne sur ton Mac (local-exec) pour :
#   1. Récupérer le token "add-node" depuis le master
#   2. L'envoyer aux deux workers pour qu'ils rejoignent le cluster
resource "null_resource" "join_workers" {
  depends_on = [
    azurerm_linux_virtual_machine.k8s_master,
    azurerm_linux_virtual_machine.k8s_workers
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/join-workers.sh"
    environment = {
      MASTER_IP        = azurerm_public_ip.k8s_master_pip.ip_address
      WORKER1_IP       = azurerm_network_interface.k8s_worker_nic["worker-1"].private_ip_address
      WORKER2_IP       = azurerm_network_interface.k8s_worker_nic["worker-2"].private_ip_address
      SSH_PRIVATE_KEY  = var.ssh_private_key_path
      MASTER_PRIVATE_IP = azurerm_network_interface.k8s_master_nic.private_ip_address
    }
  }
}
