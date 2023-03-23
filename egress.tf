resource "azurerm_subnet" "firewall" {
  count = var.private ? 1 : 0

  name                 = "${var.name_prefix}-firewall"
  resource_group_name  = data.azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [local.subnets_firewall]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

resource "azurerm_public_ip" "firewall" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-firewall"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_firewall" "firewall" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-firewall"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "${var.name_prefix}-firewall"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

resource "azurerm_route_table" "firewall" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-firewall"
  resource_group_name = data.azurerm_resource_group.aro.name
  location            = data.azurerm_resource_group.aro.location
  tags                = var.tags

  # ARO User Define Routing Route
  route {
    name                   = "${var.name_prefix}-udr"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall[0].ip_configuration[0].private_ip_address
  }

  # Local Route for internal VNet
  route {
    name           = "${var.name_prefix}-local"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "VirtualNetworkGateway"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# TODO: Restrict the FW Network Rules
resource "azurerm_firewall_network_rule_collection" "firewall" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-https"
  azure_firewall_name = azurerm_firewall.firewall[0].name
  resource_group_name = data.azurerm_resource_group.aro.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "${var.name_prefix}-allow-all"
    source_addresses = [
      "*",
    ]
    destination_addresses = [
      "*"
    ]
    protocols = [
      "Any"
    ]
    destination_ports = [
      "1-65535",
    ]
  }
}


resource "azurerm_firewall_application_rule_collection" "aro" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-aro"
  azure_firewall_name = azurerm_firewall.firewall[0].name
  resource_group_name = data.azurerm_resource_group.aro.name
  priority            = 101
  action              = "Allow"

  rule {
    name = "${var.name_prefix}-aro-required"
    source_addresses = [
      "*",
    ]
    target_fqdns = [
      "cert-api.access.redhat.com",
      "api.openshift.com",
      "api.access.redhat.com",
      "infogw.api.openshift.com",
      "registry.redhat.io",
      "access.redhat.com",
      "*.quay.io",
      "sso.redhat.com",
      "*.openshiftapps.com",
      "mirror.openshift.com",
      "registry.access.redhat.com",
      "*.redhat.com",
      "*.openshift.com"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }

  rule {
    name = "${var.name_prefix}-aro-specific"
    source_addresses = [
      "*",
    ]
    target_fqdns = [
      "*.azurecr.io",
      "*.azure.com",
      "login.microsoftonline.com",
      "*.windows.net",
      "dc.services.visualstudio.com",
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.monitoring.azure.com",
      "*.azure.cn"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }
}


resource "azurerm_firewall_application_rule_collection" "docker" {
  count = var.private ? 1 : 0

  name                = "${var.name_prefix}-docker"
  azure_firewall_name = azurerm_firewall.firewall[0].name
  resource_group_name = data.azurerm_resource_group.aro.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "${var.name_prefix}-docker"
    source_addresses = [
      "*",
    ]
    target_fqdns = [
      "*cloudflare.docker.com",
      "*registry-1.docker.io",
      "apt.dockerproject.org",
      "auth.docker.io"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }
}

resource "azurerm_subnet_route_table_association" "firewall_control_plane" {
  count = var.private ? 1 : 0

  subnet_id      = azurerm_subnet.control_plane.id
  route_table_id = azurerm_route_table.firewall[0].id
}

resource "azurerm_subnet_route_table_association" "firewall_worker" {
  count = var.private ? 1 : 0

  subnet_id      = azurerm_subnet.worker.id
  route_table_id = azurerm_route_table.firewall[0].id
}
