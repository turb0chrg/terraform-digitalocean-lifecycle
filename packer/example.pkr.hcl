variable "azureregion" {
  type    = string
  default = "uksouth"
}

variable "azuresize" {
  type    = string
  default = "Standard_F4s_v2" #4 vCPU 8 GB RAM
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

  subscription_id  =  "b4e8b4c8-1272-4fb1-92b8-c740ac9c4440"

  os_type = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "18.04-LTS"
 
  managed_image_name                = "example-${var.imageversion}-${var.siteversion}"
  managed_image_resource_group_name = "terraform-azure-lifecycle-rg"
  location                          = "${var.azureregion}"

  vm_size      = "${var.azuresize}"
}

build {
  sources = ["source.azure-arm.source01"]

  provisioner "ansible" {
    extra_arguments = ["--extra-vars", "siteversion=${var.siteversion}"]
    playbook_file   = "./ansible_playbook/prepare.yml"
  }
}
