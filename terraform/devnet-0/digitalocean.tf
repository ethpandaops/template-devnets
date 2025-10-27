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
  base_cidr_block = var.base_cidr_block
  digitalocean_vpcs = {
    for region in var.digitalocean_regions : region => {
      name     = "${var.ethereum_network}-${region}"
      region   = region
      ip_range = cidrsubnet(local.base_cidr_block, 8, index(var.digitalocean_regions, region))
    }
  }
}

locals {
  digitalocean_vm_groups = flatten([
    for vm_group in local.vm_groups :
    vm_group.count > 0 ? [
      for i in range(0, vm_group.count) : {
        group_name = "${vm_group.name}"
        id         = "${vm_group.name}-${i + 1}"
        vms = {
          "${i + 1}" = {
            tags = join(",", compact([
              "group_name:${vm_group.name}",
              "val_start:${vm_group.validator_start + (i * (vm_group.validator_end - vm_group.validator_start) / vm_group.count)}",
              "val_end:${min(vm_group.validator_start + ((i + 1) * (vm_group.validator_end - vm_group.validator_start) / vm_group.count), vm_group.validator_end)}",
              "supernode:${try(vm_group.supernode, can(regex("(super|bootnode|mev)", vm_group.name))) ? "True" : "False"}",
              can(regex("bootnode", vm_group.name)) ? "bootnode:${var.ethereum_network}" : null,
              can(regex("mev-relay", vm_group.name)) ? "mev-relay:${var.ethereum_network}" : null
            ]))
            region = try(vm_group.region, var.digitalocean_regions[i % length(var.digitalocean_regions)])
            size   = try(vm_group.size, can(regex("(super|bootnode)", vm_group.name)) ? var.digitalocean_supernode_size : var.digitalocean_fullnode_size)
            ipv6   = try(vm_group.ipv6, true)
          }
        }
      }
    ] : []
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

  # flatten vm_groups so that we can use it with for_each()
  digitalocean_vms = flatten([
    for group in local.digitalocean_vm_groups : [
      for vm_key, vm in group.vms : {
        id        = "${group.id}"
        group_key = "${group.group_name}"
        vm_key    = vm_key

        name         = try(vm.name, "${group.id}")
        ssh_keys     = try(vm.ssh_keys, [data.digitalocean_ssh_key.main.fingerprint])
        region       = try(vm.region, try(group.region, local.digitalocean_default_region))
        image        = try(vm.image, local.digitalocean_default_image)
        size         = try(vm.size, local.digitalocean_default_size)
        resize_disk  = try(vm.resize_disk, true)
        monitoring   = try(vm.monitoring, true)
        backups      = try(vm.backups, false)
        ipv6         = try(vm.ipv6, true)
        ansible_vars = try(vm.ansible_vars, null)
        vpc_uuid = try(vm.vpc_uuid, try(
          digitalocean_vpc.main[vm.region].id,
          digitalocean_vpc.main[try(group.region, local.digitalocean_default_region)].id
        ))

        tags = concat(local.digitalocean_global_tags, try(split(",", group.tags), []), try(split(",", vm.tags), []))
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
    for vm in local.digitalocean_vms : "${vm.id}" => vm
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



////////////////////////////////////////////////////////////////////////////////////////
//                          GENERATED FILES AND OUTPUTS
////////////////////////////////////////////////////////////////////////////////////////

resource "local_file" "ansible_inventory" {
  content = templatefile("ansible_inventory.tmpl",
    {
      ethereum_network_name = "${var.ethereum_network}"
      groups = merge(
        { for group in local.digitalocean_vm_groups : "${group.group_name}" => true... },
      )
      hosts = merge(
        {
          for key, server in digitalocean_droplet.main : "do.${key}" => {
            ip              = "${server.ipv4_address}"
            ipv6            = try(server.ipv6_address, "none")
            group           = try([for tag in tolist(server.tags) : split(":", tag)[1] if can(regex("^group_name:", tag))][0], "unknown")
            validator_start = try([for tag in tolist(server.tags) : split(":", tag)[1] if can(regex("^val_start:", tag))][0], 0)
            validator_end   = try([for tag in tolist(server.tags) : split(":", tag)[1] if can(regex("^val_end:", tag))][0], 0)
            supernode       = try(title([for tag in tolist(server.tags) : split(":", tag)[1] if can(regex("^supernode:", tag))][0]), "undefined")
            tags            = "${server.tags}"
            hostname        = "${split(".", key)[0]}"
            cloud           = "digitalocean"
            region          = "${server.region}"
          }
        }
      )
    }
  )
  filename = "../../ansible/inventories/devnet-0/inventory.ini"
}

locals {
  ssh_config_path = pathexpand("~/.ssh/config.d/ssh_config.${var.ethereum_network}.digitalocean")
}

resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/ssh_config.tmpl",
    {
      ethereum_network = var.ethereum_network
      hosts = merge(
        {
          for key, server in digitalocean_droplet.main : "${var.ethereum_network}-${key}" => {
            hostname   = server.ipv4_address
            private_ip = server.ipv4_address_private
            name       = key
            user       = "devops"
          }
        }
      )
    }
  )
  filename = local.ssh_config_path

  depends_on = [digitalocean_droplet.main]

  lifecycle {
    create_before_destroy = true
  }
}

# Ensure cleanup on destroy
resource "null_resource" "ssh_config_cleanup" {
  triggers = {
    ssh_config_path = local.ssh_config_path
  }

  # This provisioner runs on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${self.triggers.ssh_config_path} || true"
  }

  depends_on = [local_file.ssh_config]
}

output "ssh_config_file" {
  value       = "SSH config generated at: ${local.ssh_config_path}"
  description = "Path to the generated SSH config file"
}
