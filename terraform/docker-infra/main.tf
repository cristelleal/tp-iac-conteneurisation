# ─────────────────────────────────────────────────────────────────
# TERRAFORM — Infrastructure Docker sur Azure
#
# Ce fichier crée :
#   - Un groupe de ressources Azure
#   - Un réseau virtuel (VNet) + sous-réseau
#   - Un pare-feu (Network Security Group) : ports 22, 80, 443
#   - Une IP publique + interface réseau
#   - Une VM Ubuntu 22.04 (Standard_B2s : 2 vCPU, 4 GB RAM)
#   - L'installation automatique de Docker via remote-exec
#   - Le déploiement de l'application via docker compose
# ─────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Le provider Azure lit les credentials depuis "az login"
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}

# ─── GROUPE DE RESSOURCES ───────────────────────────────────────
# Conteneur logique pour toutes les ressources Docker
resource "azurerm_resource_group" "docker_rg" {
  name     = var.resource_group_name
  location = var.location
}

# ─── RÉSEAU VIRTUEL ─────────────────────────────────────────────
resource "azurerm_virtual_network" "docker_vnet" {
  name                = "docker-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name
}

resource "azurerm_subnet" "docker_subnet" {
  name                 = "docker-subnet"
  resource_group_name  = azurerm_resource_group.docker_rg.name
  virtual_network_name = azurerm_virtual_network.docker_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ─── PARE-FEU (Network Security Group) ──────────────────────────
# Définit quels ports sont accessibles depuis internet
resource "azurerm_network_security_group" "docker_nsg" {
  name                = "docker-nsg"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  # SSH : administration de la VM
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

  # HTTP : accès à l'application web
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

  # HTTPS : accès sécurisé (prévu pour l'avenir)
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
}

# ─── IP PUBLIQUE ────────────────────────────────────────────────
resource "azurerm_public_ip" "docker_pip" {
  name                = "docker-public-ip"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─── INTERFACE RÉSEAU ───────────────────────────────────────────
resource "azurerm_network_interface" "docker_nic" {
  name                = "docker-nic"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.docker_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.docker_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "docker_nic_nsg" {
  network_interface_id      = azurerm_network_interface.docker_nic.id
  network_security_group_id = azurerm_network_security_group.docker_nsg.id
}

# ─── MACHINE VIRTUELLE ──────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "docker_vm" {
  name                = "docker-host"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  size                = var.vm_size          # Standard_B2s : 2 vCPU, 4 GB
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.docker_nic.id]

  # Authentification par clé SSH (plus sécurisé qu'un mot de passe)
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # ── Provisioner : installe Docker et lance l'application ──
  # "connection" définit comment Terraform se connecte à la VM via SSH
  connection {
    type        = "ssh"
    host        = self.public_ip_address
    user        = "azureuser"
    private_key = file(var.ssh_private_key_path)
  }

  # Étape 1 : copier les fichiers nécessaires sur la VM
  # On copie le docker-compose de prod (sans "build:", utilise l'image Docker Hub)
  provisioner "file" {
    source      = "${path.module}/docker-compose.prod.yml"
    destination = "/home/azureuser/docker-compose.yml"
  }

  provisioner "file" {
    source      = "${path.module}/../../docker/nginx"
    destination = "/home/azureuser/nginx"
  }

  provisioner "file" {
    source      = "${path.module}/../../database"
    destination = "/home/azureuser/database"
  }

  # Étape 2 : exécuter le script d'installation
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup-docker.sh"
  }
}
