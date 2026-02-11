////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "hcloud_ssh_key_fingerprint" {
  type    = string
  default = "d6:76:2d:9c:5b:33:80:ff:0f:09:a2:10:9b:58:7e:dc"
}

variable "hetzner_supernode_size" {
  type    = string
  default = "cax41"
}

variable "hetzner_fullnode_size" {
  type    = string
  default = "cax31"
}

variable "hetzner_regions" {
  default = [
    "nbg1",
    "fsn1",
    "hel1"
  ]
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  hetzner_has_servers = length(local.hetzner_nodes) > 0

  hetzner_network = {
    for region in var.hetzner_regions : region => {
      name     = "${var.ethereum_network}-${region}"
      ip_range = cidrsubnet(var.base_cidr_block, 8, index(var.hetzner_regions, region))
    }
  }
  hetzner_network_subnets = {
    for region in var.hetzner_regions : region => {
      zone     = "eu-central"
      ip_range = cidrsubnet(var.base_cidr_block, 8, index(var.hetzner_regions, region))
    }
  }
}

locals {
  hetzner_vm_groups = flatten([
    for node in local.hetzner_nodes : [
      for i in range(0, node.count) : {
        group_name = node.name
        id         = "${node.name}-${node.start_index + i + 1}"
        vms = {
          "${i + 1}" = {
            arch = can(regex("^cax", node.size != null ? node.size : (can(regex("(super|bootnode)", node.name)) ? var.hetzner_supernode_size : var.hetzner_fullnode_size))) ? "arm64" : "amd64"
            labels = join(",", compact([
              "group_name:${node.name}",
              "val_start:${node.validator_start + (i * (node.validator_end - node.validator_start) / node.count)}",
              "val_end:${min(node.validator_start + ((i + 1) * (node.validator_end - node.validator_start) / node.count), node.validator_end)}",
              "supernode:${node.supernode != null ? (node.supernode ? "True" : "False") : (can(regex("(super|bootnode|mev)", node.name)) ? "True" : "False")}",
              "arch:${can(regex("^cax", node.size != null ? node.size : (can(regex("(super|bootnode)", node.name)) ? var.hetzner_supernode_size : var.hetzner_fullnode_size))) ? "arm64" : "amd64"}",
              can(regex("bootnode", node.name)) ? "bootnode:${var.ethereum_network}" : null,
              can(regex("mev-relay", node.name)) ? "mev:${var.ethereum_network}" : null
            ]))
            location     = node.location != null ? node.location : var.hetzner_regions[i % length(var.hetzner_regions)]
            size         = node.size != null ? node.size : (can(regex("(super|bootnode)", node.name)) ? var.hetzner_supernode_size : var.hetzner_fullnode_size)
            ipv4_enabled = node.ipv4_enabled
            ipv6_enabled = node.ipv6_enabled
          }
        }
      }
    ]
  ])
}

locals {
  hcloud_default_location    = "nbg1"
  hcloud_default_image       = "debian-13"
  hcloud_default_server_type = var.hetzner_fullnode_size
  hcloud_global_labels = [
    "Owner:Devops",
    "EthNetwork:${var.ethereum_network}"
  ]

  hcloud_vms = flatten([
    for group in local.hetzner_vm_groups : [
      for vm_key, vm in group.vms : {
        id        = group.id
        group_key = group.group_name
        vm_key    = vm_key

        name         = group.id
        ipv4_enabled = vm.ipv4_enabled
        ipv6_enabled = vm.ipv6_enabled
        ssh_keys     = local.hetzner_has_servers ? [data.hcloud_ssh_key.main[0].id] : []
        location     = vm.location
        image        = local.hcloud_default_image
        server_type  = vm.size
        backups      = false

        labels = concat(local.hcloud_global_labels, split(",", vm.labels))
      }
    ]
  ])
}

////////////////////////////////////////////////////////////////////////////////////////
//                                  HETZNER RESOURCES
////////////////////////////////////////////////////////////////////////////////////////
resource "hcloud_network" "main" {
  for_each = local.hetzner_has_servers ? local.hetzner_network : {}
  name     = each.value.name
  ip_range = each.value.ip_range
}

resource "hcloud_network_subnet" "main" {
  for_each     = local.hetzner_has_servers ? local.hetzner_network_subnets : {}
  network_id   = hcloud_network.main[each.key].id
  type         = "cloud"
  network_zone = each.value.zone
  ip_range     = each.value.ip_range
}

data "hcloud_ssh_key" "main" {
  count       = local.hetzner_has_servers ? 1 : 0
  fingerprint = var.hcloud_ssh_key_fingerprint
}

resource "hcloud_server" "main" {
  for_each = {
    for vm in local.hcloud_vms : vm.id => vm
  }
  name        = "${var.ethereum_network}-${each.value.name}"
  image       = each.value.image
  server_type = each.value.server_type
  location    = each.value.location
  ssh_keys    = each.value.ssh_keys
  backups     = each.value.backups
  labels      = { for label in each.value.labels : split(":", label)[0] => split(":", label)[1] }
  public_net {
    ipv4_enabled = each.value.ipv4_enabled
    ipv6_enabled = each.value.ipv6_enabled
  }
}

resource "hcloud_server_network" "main" {
  for_each = {
    for vm in local.hcloud_vms : vm.id => vm
  }
  server_id  = hcloud_server.main[each.key].id
  network_id = hcloud_network.main[each.value.location].id
}
