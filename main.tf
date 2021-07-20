terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.60.0" #May 20, 2021 -pinning to last .10 release
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "b4e8b4c8-1272-4fb1-92b8-c740ac9c4440"
}

locals {
  ubuntuversion = "18-04"
  azuresize     = "Standard_B1s"
  location      = "uksouth"
}

variable "siteversion" {
  default = "1"
}

variable "resourcegroupname" {
  default = "terraform-azure-lifecycle-rg"
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/image
data "azurerm_image" "example1" {
  resource_group_name = var.resourcegroupname
  name                = "example-ubuntu-${local.ubuntuversion}-x64-${var.siteversion}" #https://www.packer.io/docs/builders/azure/arm
}

resource "azurerm_resource_group" "example1" {
  name     = var.resourcegroupname
  location = local.location
}

resource "azurerm_virtual_network" "example01" {
  name                = "example-vnet"
  location            = local.location
  resource_group_name = azurerm_resource_group.example1.name
  address_space       = ["10.192.6.0/24"]

}

resource "azurerm_subnet" "subnet01" {
  name                 = "snet-dns-authentication"
  resource_group_name  = azurerm_resource_group.example1.name
  virtual_network_name = azurerm_virtual_network.example01.name
  address_prefixes     = ["10.192.6.0/27"]
}

resource "azurerm_network_interface" "web_nic" {
  name                = "web-${format("%02d", count.index + 1)}-nic-01"
  location            = local.location
  resource_group_name = azurerm_resource_group.example1.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Dynamic"
  }

  count = 2
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "web" {
  name                = "web-${count.index}"
  resource_group_name = azurerm_resource_group.example1

  location = local.location
  size     = local.azuresize

  source_image_id = data.azurerm_image.example1.id

  network_interface_ids = [azurerm_network_interface.web_nic[count.index].id]

  admin_username = "symadmin"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  lifecycle {
    create_before_destroy = true
  }

  # provisioner "local-exec" {
  #   command = "./check_health.sh ${self.ipv4_address}"
  # }

  count = 2
}

# resource "digitalocean_loadbalancer" "public" {
#   name        = "loadbalancer-1"
#   region      = "lon1"
#   azure_tag = "zero-downtime"

#   forwarding_rule {
#     entry_port     = 80
#     entry_protocol = "http"

#     target_port     = 80
#     target_protocol = "http"
#   }

#   healthcheck {
#     port                   = 80
#     protocol               = "http"
#     path                   = "/"
#     check_interval_seconds = "5"
#   }
# }

# output "lb_ip" {
#   value = "${digitalocean_loadbalancer.public.ip}"
# }
