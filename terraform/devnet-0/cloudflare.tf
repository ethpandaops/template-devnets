
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
        name     = vm.name
        has_ipv6 = vm.ipv6
        ipv4     = digitalocean_droplet.main[vm.id].ipv4_address
        ipv6     = try(digitalocean_droplet.main[vm.id].ipv6_address, null)
      } if can(regex("bootnode", vm.name))
    },
    {
      for vm in local.hcloud_vms : vm.id => {
        name     = vm.name
        has_ipv6 = vm.ipv6_enabled
        ipv4     = hcloud_server.main[vm.id].ipv4_address
        ipv6     = try(hcloud_server.main[vm.id].ipv6_address, null)
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
  for_each = { for k, v in local.bootnodes : k => v if v.has_ipv6 }
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

////////////////////////////////////////////////////////////////////////////////////////
//                                 PUBLIC HOSTS
////////////////////////////////////////////////////////////////////////////////////////

# <network>.ethpandaops.io and *.<network>.ethpandaops.io, proxied by Cloudflare
# to the cluster that runs the devnet's charts in kubernetes/<devnet>.
locals {
  tunnel_cname = "68eb8c26-dcfb-4f80-aab1-3263154e76f2.cfargotunnel.com"
}

# Full names: an existing record imported into this state reads back with its
# full name, and provider v3 would replace it over a short one.
resource "cloudflare_record" "public" {
  zone_id = data.cloudflare_zone.default.id
  name    = "${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  type    = "CNAME"
  value   = local.tunnel_cname
  proxied = true
}

resource "cloudflare_record" "public_star" {
  zone_id = data.cloudflare_zone.default.id
  name    = "*.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  type    = "CNAME"
  value   = local.tunnel_cname
  proxied = true
}

# Universal SSL covers only one level below ethpandaops.io, so the second level
# needs its own certificate.
resource "cloudflare_certificate_pack" "public" {
  zone_id                = data.cloudflare_zone.default.id
  type                   = "advanced"
  hosts                  = ["*.${var.ethereum_network}.${data.cloudflare_zone.default.name}"]
  validation_method      = "txt"
  validity_days          = 90
  certificate_authority  = "lets_encrypt"
  cloudflare_branding    = false
  wait_for_active_status = true
}
