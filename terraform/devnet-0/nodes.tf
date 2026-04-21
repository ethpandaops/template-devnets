########################################################################################
#                                    NODE DEFINITIONS
#
# Define your fleet as a list of node entries. Each entry supports:
#
#   Required:
#     - name            : Node type (e.g., "lighthouse-geth-super", "bootnode")
#     - count           : Number of instances
#     - cloud           : "digitalocean" or "hetzner"
#
#   Optional:
#     - validator_start : First validator index (default: 0)
#     - validator_end   : Last validator index (default: 0)
#     - size            : Instance size override (provider-specific)
#     - region          : Region override (digitalocean) or location (hetzner)
#     - supernode       : Force supernode=true/false (auto-detected from name)
#
# Examples:
#   { name = "bootnode", count = 1, cloud = "digitalocean" }
#   { name = "lighthouse-geth-super", count = 2, cloud = "hetzner", validator_start = 0, validator_end = 200 }
#   { name = "mev-relay", count = 1, cloud = "hetzner", size = "ccx53" }
#
########################################################################################

variable "nodes" {
  description = "List of node definitions for the devnet"
  default = [
    { name = "bootnode", count = 1, cloud = "digitalocean" },
    { name = "mev-relay", count = 1, cloud = "hetzner", size = "ccx53" },
    { name = "lighthouse-geth", count = 2, cloud = "digitalocean", validator_start = 0, validator_end = 400 },
    { name = "lighthouse-geth", count = 1, cloud = "hetzner", validator_start = 400, validator_end = 500 },
    { name = "prysm-nethermind", count = 1, cloud = "hetzner", validator_start = 500, validator_end = 550 },
  ]
}
