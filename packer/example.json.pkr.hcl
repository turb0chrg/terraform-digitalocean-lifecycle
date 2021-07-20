
variable "azureregion" {
  type    = string
  default = "uksouth"
}

variable "azuresize" {
  type    = string
  default = "Standard_B1s"
}

variable "siteversion" {
  type    = string
  default = "1"
}

variable "imageversion" {
  type    = string
  default = "18-04"
}

#https://www.packer.io/docs/builders/azure
source "azure-arm" "source01" {

  os_type = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer" #"0001-com-ubuntu-server-bionic" #Ubuntu Server 18.04 LTS  ?
  image_sku       = "18.04-LTS"
 
  managed_image_name                = "example-${var.imageversion}-${var.siteversion}"
  managed_image_resource_group_name = "terraform-azure-lifecycle"
  location                          = "${var.azureregion}"

  vm_size          = "${var.azuresize}"
  ssh_username  = "root"
}

build {
  sources = ["source.azure-arm.source01"]

  provisioner "ansible" {
    extra_arguments = ["--extra-vars", "siteversion=${var.siteversion}"]
    playbook_file   = "./ansible_playbook/prepare.yml"
  }

}
