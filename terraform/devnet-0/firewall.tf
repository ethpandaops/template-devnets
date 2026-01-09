
resource "digitalocean_firewall" "main" {
  name = "${var.ethereum_network}-nodes"
  // Tags are used to select which droplets should
  // be assigned to this firewall.
  tags = [
    "EthNetwork:${var.ethereum_network}"
  ]

  // SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Allow all inbound ICMP
  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Nginx / Web
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Consensus layer p2p port
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9000-9002"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "9000-9002"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Bootnode
  inbound_rule {
    protocol         = "udp"
    port_range       = "9010"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Execution layer p2p Port
  inbound_rule {
    protocol         = "tcp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "42069"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "42069"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Engine rpc-snooper api
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8961"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  depends_on = [digitalocean_project_resources.droplets]
}

resource "digitalocean_firewall" "bootnode" {
  name = "${var.ethereum_network}-nodes-bootnode"
  // Tags are used to select which droplets should
  // be assigned to this firewall.
  tags = [
    "bootnode:${var.ethereum_network}"
  ]

  // DNS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "53"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "53"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  depends_on = [digitalocean_project_resources.droplets]
}

resource "digitalocean_firewall" "mev_relay" {
  count       = contains(keys(digitalocean_droplet.main), "mev-relay-1") ? 1 : 0
  name        = "${var.ethereum_network}-nodes-mev-relay"
  tags        = ["mev-relay:${var.ethereum_network}"]

  // mev-relay ports
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9060-9062"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  depends_on = [digitalocean_project_resources.droplets]
}
