////////////////////////////////////////////////////////////////////////////////////////
//                          GENERATED FILES AND OUTPUTS
////////////////////////////////////////////////////////////////////////////////////////

resource "local_file" "ansible_inventory" {
  content = templatefile("ansible_inventory.tmpl",
    {
      ethereum_network_name = "${var.ethereum_network}"
      groups = merge(
        { for group in local.digitalocean_vm_groups : "${group.group_name}" => true... },
        { for group in local.hetzner_vm_groups : "${group.group_name}" => true... },
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
            arch            = try([for tag in tolist(server.tags) : split(":", tag)[1] if can(regex("^arch:", tag))][0], "amd64")
            tags            = "${server.tags}"
            hostname        = "${split(".", key)[0]}"
            cloud           = "digitalocean"
            region          = "${server.region}"
          }
        },
        {
          for key, server in hcloud_server.main : "${key}" => {
            ip              = coalesce(server.ipv4_address, (try(server.ipv6_address, "")))
            ipv6            = coalesce(server.ipv6_address, "")
            group           = server.labels.group_name
            validator_start = server.labels.val_start
            validator_end   = server.labels.val_end
            supernode       = server.labels.supernode
            arch            = server.labels.arch
            tags            = server.labels
            hostname        = split(".", key)[0]
            cloud           = "hetzner"
            region          = server.datacenter
          }
        }
      )
    }
  )
  filename = "../../ansible/inventories/devnet-0/inventory.ini"
}

locals {
  ssh_config_path = pathexpand("~/.ssh/config.d/ssh_config.${var.ethereum_network}")
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
        },
        {
          for key, server in hcloud_server.main : "${var.ethereum_network}-${key}" => {
            hostname   = coalesce(server.ipv4_address, (try(server.ipv6_address, "")))
            private_ip = try(hcloud_server_network.main[key].ip, "")
            name       = key
            user       = "devops"
          }
        }
      )
    }
  )
  filename = local.ssh_config_path

  depends_on = [digitalocean_droplet.main, hcloud_server.main]

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "ssh_config_cleanup" {
  triggers = {
    ssh_config_path = local.ssh_config_path
  }

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

output "digitalocean_server_count" {
  value       = length(digitalocean_droplet.main)
  description = "Number of DigitalOcean servers created"
}

output "hetzner_server_count" {
  value       = length(hcloud_server.main)
  description = "Number of Hetzner servers created"
}

output "total_server_count" {
  value       = length(digitalocean_droplet.main) + length(hcloud_server.main)
  description = "Total number of servers created across all providers"
}
