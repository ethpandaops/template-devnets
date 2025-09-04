////////////////////////////////////////////////////////////////////////////////////////
//                                   DNS NAMES
////////////////////////////////////////////////////////////////////////////////////////

data "cloudflare_zone" "default" {
  name = "ethpandaops.io"
}

resource "cloudflare_record" "server_record" {
  for_each = {
    for vm in local.hcloud_vms : "${vm.id}" => vm if coalesce(vm.ipv4_enabled, true) == true && can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "${each.value.name}.${var.ethereum_network}"
  type    = "A"
  value   = hcloud_server.main[each.value.id].ipv4_address
  proxied = false
  ttl     = 120
}

resource "cloudflare_record" "server_record6" {
  for_each = {
    for vm in local.hcloud_vms : "${vm.id}" => vm if coalesce(vm.ipv6_enabled, true) == true && can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "${each.value.name}.${var.ethereum_network}"
  type    = "AAAA"
  value   = hcloud_server.main[each.value.id].ipv6_address
  proxied = false
  ttl     = 120
}

resource "cloudflare_record" "server_record_ns" {
  for_each = {
    for vm in local.hcloud_vms : "${vm.id}" => vm if can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "srv.${var.ethereum_network}"
  type    = "NS"
  value   = "${each.value.name}.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  proxied = false
  ttl     = 120
}