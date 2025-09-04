# Bootnode
variable "bootnode" {
  default = {
    name            = "bootnode"
    count           = 1
    validator_start = 0
    validator_end   = 0
  }
}

# Supernodes
# Lighthouse
variable "lighthouse_geth_super" {
  default = {
    name            = "lighthouse-geth-super"
    count           = 1
    validator_start = 0
    validator_end   = 100
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
variable "lighthouse_geth" {
  default = {
    name            = "lighthouse-geth"
    count           = 1
    validator_start = 0
    validator_end   = 100
  }
}

variable "lighthouse_besu" {
  default = {
    name            = "lighthouse-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nethermind" {
  default = {
    name            = "lighthouse-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_erigon" {
  default = {
    name            = "lighthouse-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_reth" {
  default = {
    name            = "lighthouse-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lighthouse_nimbusel" {
  default = {
    name            = "lighthouse-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Prysm
variable "prysm_geth" {
  default = {
    name            = "prysm-geth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_besu" {
  default = {
    name            = "prysm-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nethermind" {
  default = {
    name            = "prysm-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_erigon" {
  default = {
    name            = "prysm-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_reth" {
  default = {
    name            = "prysm-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "prysm_nimbusel" {
  default = {
    name            = "prysm-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Lodestar
variable "lodestar_geth" {
  default = {
    name            = "lodestar-geth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nethermind" {
  default = {
    name            = "lodestar-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_besu" {
  default = {
    name            = "lodestar-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_erigon" {
  default = {
    name            = "lodestar-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_reth" {
  default = {
    name            = "lodestar-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "lodestar_nimbusel" {
  default = {
    name            = "lodestar-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Nimbus
variable "nimbus_geth" {
  default = {
    name            = "nimbus-geth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_besu" {
  default = {
    name            = "nimbus-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nethermind" {
  default = {
    name            = "nimbus-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_erigon" {
  default = {
    name            = "nimbus-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_reth" {
  default = {
    name            = "nimbus-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "nimbus_nimbusel" {
  default = {
    name            = "nimbus-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Teku
variable "teku_geth" {
  default = {
    name            = "teku-geth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_besu" {
  default = {
    name            = "teku-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nethermind" {
  default = {
    name            = "teku-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_erigon" {
  default = {
    name            = "teku-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_reth" {
  default = {
    name            = "teku-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "teku_nimbusel" {
  default = {
    name            = "teku-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

# Grandine
variable "grandine_geth" {
  default = {
    name            = "grandine-geth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_besu" {
  default = {
    name            = "grandine-besu"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nethermind" {
  default = {
    name            = "grandine-nethermind"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_erigon" {
  default = {
    name            = "grandine-erigon"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_reth" {
  default = {
    name            = "grandine-reth"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}

variable "grandine_nimbusel" {
  default = {
    name            = "grandine-nimbusel"
    count           = 0
    validator_start = 0
    validator_end   = 0
  }
}