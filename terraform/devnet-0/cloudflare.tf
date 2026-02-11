
////////////////////////////////////////////////////////////////////////////////////////
//                                   DNS NAMES
////////////////////////////////////////////////////////////////////////////////////////

data "cloudflare_zone" "default" {
  name = "ethpandaops.io"
}

locals {
  # Combine bootnodes from both providers
  bootnodes = merge(
    {
      for vm in local.digitalocean_vms : vm.id => {
        name = vm.name
        ipv4 = digitalocean_droplet.main[vm.id].ipv4_address
        ipv6 = try(digitalocean_droplet.main[vm.id].ipv6_address, null)
      } if can(regex("bootnode", vm.name))
    },
    {
      for vm in local.hcloud_vms : vm.id => {
        name = vm.name
        ipv4 = hcloud_server.main[vm.id].ipv4_address
        ipv6 = try(hcloud_server.main[vm.id].ipv6_address, null)
      } if can(regex("bootnode", vm.name))
    }
  )
}

resource "cloudflare_record" "server_record_v4" {
  for_each = local.bootnodes
  zone_id  = data.cloudflare_zone.default.id
  name     = "${each.value.name}.${var.ethereum_network}"
  type     = "A"
  value    = each.value.ipv4
  proxied  = false
  ttl      = 120
}

resource "cloudflare_record" "server_record_v6" {
  for_each = { for k, v in local.bootnodes : k => v if v.ipv6 != null }
  zone_id  = data.cloudflare_zone.default.id
  name     = "${each.value.name}.${var.ethereum_network}"
  type     = "AAAA"
  value    = each.value.ipv6
  proxied  = false
  ttl      = 120
}

resource "cloudflare_record" "server_record_ns" {
  for_each = local.bootnodes
  zone_id  = data.cloudflare_zone.default.id
  name     = "srv.${var.ethereum_network}"
  type     = "NS"
  value    = "${each.value.name}.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  proxied  = false
  ttl      = 120
}
