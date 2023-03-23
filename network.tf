
#
# resource group
#
data "azurerm_resource_group" "aro" {
  name = var.resource_group
}

#
# vnet
#
resource "azurerm_virtual_network" "aro" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vpc_cidr]
  location            = data.azurerm_resource_group.aro.location
  resource_group_name = data.azurerm_resource_group.aro.name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

#
# subnets
#
locals {
  subnet_slices = var.private ? 4 : 2
  subnet_cidrs  = [for index in range(2) : cidrsubnet(var.vpc_cidr, local.subnet_slices, index)]

  subnets_control  = local.subnet_cidrs[0]
  subnets_worker   = local.subnet_cidrs[1]
  subnets_jumphost = var.private ? local.subnet_cidrs[2] : null
}

resource "azurerm_subnet" "control_plane" {
  name                                          = "${var.name_prefix}-control"
  resource_group_name                           = data.azurerm_resource_group.aro.name
  virtual_network_name                          = azurerm_virtual_network.aro.name
  address_prefixes                              = [local.subnets_control]
  private_link_service_network_policies_enabled = false
  service_endpoints                             = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "worker" {
  name                 = "${var.name_prefix}-worker"
  resource_group_name  = data.azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [local.subnets_worker]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}
