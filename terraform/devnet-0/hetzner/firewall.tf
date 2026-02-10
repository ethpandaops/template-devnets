resource "hcloud_firewall" "machine_firewall" {
  name = "${var.ethereum_network}-firewall"

  apply_to {
    label_selector = "EthNetwork=${var.ethereum_network}"
  }

  # SSH
  rule {
    description = "Allow SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Allow all inbound ICMP
  rule {
    description = "Allow all inbound ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Nginx / Web
  rule {
    description = "Allow HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Consensus layer p2p port
  rule {
    description = "Allow consensus p2p port TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "9000-9002"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow consensus p2p port UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "9000-9002"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Execution layer p2p Port
  rule {
    description = "Allow execution p2p port TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "30303"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow execution p2p port UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "30303"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow execution torrent port TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "42069"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow execution torrent port UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "42069"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  // Engine rpc-snooper api
  rule {
    description = "Allow engine snooper api port TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "8961"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  rule {
    description     = "Allow all outbound traffic TCP"
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description     = "Allow all outbound traffic UDP"
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description     = "Allow all outbound traffic ICMP"
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}


resource "hcloud_firewall" "bootnode_firewall" {
  name = "${var.ethereum_network}-bootnode-firewall"

  apply_to {
    label_selector = "bootnode=${var.ethereum_network}"
  }

  # DNS
  rule {
    description = "Allow DNS UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "53"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "Allow DNS TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "53"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  // Bootnodoor P2P
  rule {
    description = "Allow Bootnodoor P2P port TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "9010"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "Allow Bootnodoor P2P port UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "9010"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "mev_relay_firewall" {
  name = "${var.ethereum_network}-mev-relay-firewall"

  apply_to {
    label_selector = "mev=${var.ethereum_network}"
  }

  rule {
    description = "Allow MEV Relay ports"
    direction   = "in"
    protocol    = "tcp"
    port        = "9060-9062"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}