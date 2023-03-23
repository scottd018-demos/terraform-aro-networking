output "public_ip" {
  value = try(azurerm_public_ip.jumphost[0].ip_address, null)
}
