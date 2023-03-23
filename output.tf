output "public_ip" {
  value = try(azurerm_public_ip.jumphost[0].ip_address, null)
}

output "vnet_id" {
  value = try(azurerm_virtual_network.aro.id, null)
}

output "control_plane_subnet_id" {
  value = try(azurerm_subnet.control_plane.id, null)
}

output "worker_subnet_id" {
  value = try(azurerm_subnet.worker.id, null)
}

output "jumphost_subnet_id" {
  value = try(azurerm_subnet.jumphost[0].id, null)
}

output "firewall_subnet_id" {
  value = try(azurerm_subnet.firewall[0].id, null)
}
