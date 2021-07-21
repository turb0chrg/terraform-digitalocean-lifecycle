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
  name                = "example-${local.ubuntuversion}-${random_pet.server.keepers.siteversion}"
}

resource "random_pet" "server" {
  keepers = {
    # Generate a new pet name each time we switch to a new AMI id
    siteversion = "${var.siteversion}"
  }
}

#terraform import azurerm_resource_group.example1 /subscriptions/b4e8b4c8-1272-4fb1-92b8-c740ac9c4440/resourceGroups/terraform-azure-lifecycle-rg
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
    public_ip_address_id          = azurerm_public_ip.vmpips[count.index].id
  }

  count = 2
}

resource "azurerm_public_ip" "vmpips" {
  name                = "pip${count.index}"
  location            = azurerm_resource_group.example1.location
  resource_group_name = azurerm_resource_group.example1.name
  allocation_method   = "Static"

  count = 2
}


# Associate network Interface and backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "assbp-01" {
  network_interface_id    = azurerm_network_interface.web_nic[count.index].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.abp-01.id

  count = 2
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "web" {
  name                = "web-${random_pet.server.id}-${count.index}"
  resource_group_name = azurerm_resource_group.example1.name

  location = local.location
  size     = local.azuresize

  source_image_id = data.azurerm_image.example1.id

  network_interface_ids = [azurerm_network_interface.web_nic[count.index].id]

  availability_set_id = azurerm_availability_set.example.id

  admin_username = "symadmin"

  admin_ssh_key {
    username   = "symadmin"
    public_key = file("id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  lifecycle {
    create_before_destroy = true
  }

  provisioner "local-exec" {
    command = "./check_health.sh ${self.public_ip_address}"
  }

  count = 2
}

resource "azurerm_availability_set" "example" {
  name                = "example-aset"
  location            = azurerm_resource_group.example1.location
  resource_group_name = azurerm_resource_group.example1.name

  platform_update_domain_count = 2
  platform_fault_domain_count  = 2
}

#LB example https://github.com/kpatnayakuni/azure-quickstart-terraform-configuration/blob/master/101-loadbalancer-with-multivip/main.tf

resource "azurerm_public_ip" "example" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.example1.location
  resource_group_name = azurerm_resource_group.example1.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lbpublic" {
  name                = "loadbalancer-1"
  location            = azurerm_resource_group.example1.location
  resource_group_name = azurerm_resource_group.example1.name

  frontend_ip_configuration {
    name                 = "loadBalancerFrontEnd1"
    public_ip_address_id = azurerm_public_ip.example.id
    private_ip_address_version    = "IPv4"
  }
}

# Backend address pool
resource "azurerm_lb_backend_address_pool" "abp-01" {
  name            = "loadBalancerBackEnd"
  loadbalancer_id = azurerm_lb.lbpublic.id
}

resource "azurerm_lb_probe" "lbpb-01" {
  name                = "tcpProbe"
  resource_group_name = azurerm_resource_group.example1.name
  port                = 80
  protocol            = "http"
  interval_in_seconds = 5
  loadbalancer_id     = azurerm_lb.lbpublic.id
  request_path        = "/"
}

# Loadbalancing rule 1
resource "azurerm_lb_rule" "lbrule-01" {
  name                           = "LBRuleForVIP1"
  resource_group_name            = azurerm_resource_group.example1.name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.abp-01.id
  loadbalancer_id                = azurerm_lb.lbpublic.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.lbpb-01.id
  frontend_ip_configuration_name = "loadBalancerFrontEnd1"
}

output "lb_ip" {
  value = azurerm_public_ip.example.ip_address
}
