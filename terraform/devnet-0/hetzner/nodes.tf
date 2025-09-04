# Bootnode
variable "bootnode" {
  default = {
    name            = "bootnode"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "mev_relay" {
  default = {
    name            = "mev-relay"
    count           = 1
    validator_start = 0
    validator_end   = 0
    size            = "ccx53"
    supernode       = true
  }
}

# Supernodes
# Lighthouse
variable "lighthouse_geth_super" {
  default = {
    name            = "lighthouse-geth-super"
    count           = 1
    validator_start = 200
    validator_end   = 300
  }
}

variable "lighthouse_besu_super" {
  default = {
    name            = "lighthouse-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nethermind_super" {
  default = {
    name            = "lighthouse-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_erigon_super" {
  default = {
    name            = "lighthouse-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_reth_super" {
  default = {
    name            = "lighthouse-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nimbusel_super" {
  default = {
    name            = "lighthouse-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Prysm
variable "prysm_geth_super" {
  default = {
    name            = "prysm-geth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_besu_super" {
  default = {
    name            = "prysm-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nethermind_super" {
  default = {
    name            = "prysm-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_erigon_super" {
  default = {
    name            = "prysm-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_reth_super" {
  default = {
    name            = "prysm-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nimbusel_super" {
  default = {
    name            = "prysm-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Lodestar
variable "lodestar_geth_super" {
  default = {
    name            = "lodestar-geth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nethermind_super" {
  default = {
    name            = "lodestar-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_besu_super" {
  default = {
    name            = "lodestar-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_erigon_super" {
  default = {
    name            = "lodestar-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_reth_super" {
  default = {
    name            = "lodestar-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nimbusel_super" {
  default = {
    name            = "lodestar-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Nimbus
variable "nimbus_geth_super" {
  default = {
    name            = "nimbus-geth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_besu_super" {
  default = {
    name            = "nimbus-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nethermind_super" {
  default = {
    name            = "nimbus-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_erigon_super" {
  default = {
    name            = "nimbus-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_reth_super" {
  default = {
    name            = "nimbus-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nimbusel_super" {
  default = {
    name            = "nimbus-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Teku
variable "teku_geth_super" {
  default = {
    name            = "teku-geth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_besu_super" {
  default = {
    name            = "teku-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nethermind_super" {
  default = {
    name            = "teku-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_erigon_super" {
  default = {
    name            = "teku-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_reth_super" {
  default = {
    name            = "teku-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nimbusel_super" {
  default = {
    name            = "teku-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Grandine
variable "grandine_geth_super" {
  default = {
    name            = "grandine-geth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_besu_super" {
  default = {
    name            = "grandine-besu-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nethermind_super" {
  default = {
    name            = "grandine-nethermind-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_erigon_super" {
  default = {
    name            = "grandine-erigon-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_reth_super" {
  default = {
    name            = "grandine-reth-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nimbusel_super" {
  default = {
    name            = "grandine-nimbusel-super"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}


# Fullnodes
# Lighthouse
variable "lighthouse_geth_full" {
  default = {
    name            = "lighthouse-geth-full"
    count           = 1
    validator_start = 300
    validator_end   = 400
  }
}

variable "lighthouse_besu_full" {
  default = {
    name            = "lighthouse-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nethermind_full" {
  default = {
    name            = "lighthouse-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_erigon_full" {
  default = {
    name            = "lighthouse-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_reth_full" {
  default = {
    name            = "lighthouse-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nimbusel_full" {
  default = {
    name            = "lighthouse-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Prysm
variable "prysm_geth_full" {
  default = {
    name            = "prysm-geth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_besu_full" {
  default = {
    name            = "prysm-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nethermind_full" {
  default = {
    name            = "prysm-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_erigon_full" {
  default = {
    name            = "prysm-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_reth_full" {
  default = {
    name            = "prysm-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nimbusel_full" {
  default = {
    name            = "prysm-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Lodestar
variable "lodestar_geth_full" {
  default = {
    name            = "lodestar-geth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nethermind_full" {
  default = {
    name            = "lodestar-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_besu_full" {
  default = {
    name            = "lodestar-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_erigon_full" {
  default = {
    name            = "lodestar-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_reth_full" {
  default = {
    name            = "lodestar-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nimbusel_full" {
  default = {
    name            = "lodestar-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Nimbus
variable "nimbus_geth_full" {
  default = {
    name            = "nimbus-geth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_besu_full" {
  default = {
    name            = "nimbus-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nethermind_full" {
  default = {
    name            = "nimbus-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_erigon_full" {
  default = {
    name            = "nimbus-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_reth_full" {
  default = {
    name            = "nimbus-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nimbusel_full" {
  default = {
    name            = "nimbus-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Teku
variable "teku_geth_full" {
  default = {
    name            = "teku-geth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_besu_full" {
  default = {
    name            = "teku-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nethermind_full" {
  default = {
    name            = "teku-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_erigon_full" {
  default = {
    name            = "teku-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_reth_full" {
  default = {
    name            = "teku-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nimbusel_full" {
  default = {
    name            = "teku-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Grandine
variable "grandine_geth_full" {
  default = {
    name            = "grandine-geth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_besu_full" {
  default = {
    name            = "grandine-besu-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nethermind_full" {
  default = {
    name            = "grandine-nethermind-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_erigon_full" {
  default = {
    name            = "grandine-erigon-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_reth_full" {
  default = {
    name            = "grandine-reth-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nimbusel_full" {
  default = {
    name            = "grandine-nimbusel-full"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}