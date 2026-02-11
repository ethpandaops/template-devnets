////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "digitalocean_project_name" {
  type    = string
  default = "Template"
}

variable "digitalocean_ssh_key_name" {
  type    = string
  default = "shared-devops-eth2"
}

variable "digitalocean_supernode_size" {
  type    = string
  default = "s-8vcpu-32gb-640gb-intel"
}

variable "digitalocean_fullnode_size" {
  type    = string
  default = "s-8vcpu-16gb"
}

variable "digitalocean_regions" {
  default = [
    "nyc1",
    "sgp1",
    "lon1",
    "nyc3",
    "ams3",
    "fra1",
    "tor1",
    "blr1",
    "sfo3",
    "syd1"
  ]
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  digitalocean_vpcs = {
    for region in var.digitalocean_regions : region => {
      name     = "${var.ethereum_network}-${region}"
      region   = region
      ip_range = cidrsubnet(var.base_cidr_block, 8, index(var.digitalocean_regions, region))
    }
  }
}

locals {
  digitalocean_vm_groups = flatten([
    for node in local.digitalocean_nodes : [
      for i in range(0, node.count) : {
        group_name = node.name
        id         = "${node.name}-${node.start_index + i + 1}"
        vms = {
          "${i + 1}" = {
            tags = join(",", compact([
              "group_name:${node.name}",
              "val_start:${node.validator_start + (i * (node.validator_end - node.validator_start) / node.count)}",
              "val_end:${min(node.validator_start + ((i + 1) * (node.validator_end - node.validator_start) / node.count), node.validator_end)}",
              "supernode:${node.supernode != null ? (node.supernode ? "True" : "False") : (can(regex("(super|bootnode|mev)", node.name)) ? "True" : "False")}",
              "arch:amd64",
              can(regex("bootnode", node.name)) ? "bootnode:${var.ethereum_network}" : null,
              can(regex("mev-relay", node.name)) ? "mev-relay:${var.ethereum_network}" : null
            ]))
            region = node.region != null ? node.region : var.digitalocean_regions[i % length(var.digitalocean_regions)]
            size   = node.size != null ? node.size : (can(regex("(super|bootnode)", node.name)) ? var.digitalocean_supernode_size : var.digitalocean_fullnode_size)
            ipv6   = node.ipv6
          }
        }
      }
    ]
  ])
}

locals {
  digitalocean_default_region = "ams3"
  digitalocean_default_size   = var.digitalocean_fullnode_size
  digitalocean_default_image  = "debian-13-x64"
  digitalocean_global_tags = [
    "Owner:Devops",
    "EthNetwork:${var.ethereum_network}"
  ]

  digitalocean_vms = flatten([
    for group in local.digitalocean_vm_groups : [
      for vm_key, vm in group.vms : {
        id        = group.id
        group_key = group.group_name
        vm_key    = vm_key

        name        = group.id
        ssh_keys    = [data.digitalocean_ssh_key.main.fingerprint]
        region      = vm.region
        image       = local.digitalocean_default_image
        size        = vm.size
        resize_disk = true
        monitoring  = true
        backups     = false
        ipv6        = vm.ipv6
        vpc_uuid    = digitalocean_vpc.main[vm.region].id

        tags = concat(local.digitalocean_global_tags, split(",", vm.tags))
      }
    ]
  ])
}

////////////////////////////////////////////////////////////////////////////////////////
//                                  DIGITALOCEAN RESOURCES
////////////////////////////////////////////////////////////////////////////////////////
data "digitalocean_project" "main" {
  name = var.digitalocean_project_name
}

data "digitalocean_ssh_key" "main" {
  name = var.digitalocean_ssh_key_name
}

resource "digitalocean_vpc" "main" {
  for_each = local.digitalocean_vpcs

  name     = each.value["name"]
  region   = each.value["region"]
  ip_range = each.value["ip_range"]
}

resource "digitalocean_droplet" "main" {
  for_each = {
    for vm in local.digitalocean_vms : vm.id => vm
  }
  name        = "${var.ethereum_network}-${each.value.name}"
  region      = each.value.region
  ssh_keys    = each.value.ssh_keys
  image       = each.value.image
  size        = each.value.size
  resize_disk = each.value.resize_disk
  monitoring  = each.value.monitoring
  backups     = each.value.backups
  ipv6        = each.value.ipv6
  vpc_uuid    = each.value.vpc_uuid
  tags        = each.value.tags
}

resource "digitalocean_project_resources" "droplets" {
  for_each  = digitalocean_droplet.main
  project   = data.digitalocean_project.main.id
  resources = [each.value.urn]
}
