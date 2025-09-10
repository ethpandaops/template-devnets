
////////////////////////////////////////////////////////////////////////////////////////
//                                   DNS NAMES
////////////////////////////////////////////////////////////////////////////////////////

data "cloudflare_zone" "default" {
  name = "ethpandaops.io"
}

resource "cloudflare_record" "server_record_v4" {
  for_each = {
    for vm in local.digitalocean_vms : "${vm.id}" => vm if can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "${each.value.name}.${var.ethereum_network}"
  type    = "A"
  value   = digitalocean_droplet.main[each.value.id].ipv4_address
  proxied = false
  ttl     = 120
}

resource "cloudflare_record" "server_record_v6" {
  for_each = {
    for vm in local.digitalocean_vms : "${vm.id}" => vm if vm.ipv6 && can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "${each.value.name}.${var.ethereum_network}"
  type    = "AAAA"
  value   = digitalocean_droplet.main[each.value.id].ipv6_address
  proxied = false
  ttl     = 120
}

resource "cloudflare_record" "server_record_ns" {
  for_each = {
    for vm in local.digitalocean_vms : "${vm.id}" => vm if can(regex("bootnode", vm.name))
  }
  zone_id = data.cloudflare_zone.default.id
  name    = "srv.${var.ethereum_network}"
  type    = "NS"
  value   = "${each.value.name}.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  proxied = false
  ttl     = 120
}

