#
# subnet
#
resource "azurerm_subnet" "jumphost" {
  count = var.private ? 1 : 0

  name                 = "${var.name_prefix}-jumphost"
  resource_group_name  = data.azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [local.subnets_jumphost]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

# Due to remote-exec issue Static allocation needs
# to be used - https://github.com/hashicorp/terraform/issues/21665
resource "azurerm_public_ip" "jumphost" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-jumphost"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  allocation_method   = "Static"
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "jumphost" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-jumphost"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumphost[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumphost[0].id
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

#
# security group
#
resource "azurerm_network_security_group" "jumphost" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-jumphost"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location

  security_rule {
    name                       = "${var.name_prefix}-jumphost-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "jumphost" {
  count = var.private ? 1 : 0

  network_interface_id      = azurerm_network_interface.jumphost[0].id
  network_security_group_id = azurerm_network_security_group.jumphost[0].id
}

#
# jumphost vm
#
resource "azurerm_linux_virtual_machine" "jumphost" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-jumphost"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  size                = "Standard_D2s_v3"
  admin_username      = "aro"
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.jumphost[0].id,
  ]

  admin_ssh_key {
    username   = "aro"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8.2"
    version   = "8.2.2021040911"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = azurerm_public_ip.jumphost[0].ip_address
      user        = "aro"
      private_key = file("~/.ssh/id_rsa")
    }
    inline = [
      "sudo dnf install telnet wget bash-completion -y",
      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz",
      "tar -xvf openshift-client-linux.tar.gz",
      "sudo mv oc kubectl /usr/bin/",
      "oc completion bash > oc_bash_completion",
      "sudo cp oc_bash_completion /etc/bash_completion.d/"
    ]
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
