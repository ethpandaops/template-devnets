////////////////////////////////////////////////////////////////////////////////////////
//                            TERRAFORM PROVIDERS & BACKEND
////////////////////////////////////////////////////////////////////////////////////////
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.28"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.42.1"
    }
  }
}

terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    endpoints                   = { s3 = "https://fra1.digitaloceanspaces.com" }
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    region                      = "us-east-1"
    bucket                      = "merge-testnets"
    key                         = "infrastructure/devnet-0/terraform.tfstate"
  }
}

provider "digitalocean" {
  http_retry_max = 20
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "ethereum_network" {
  type    = string
  default = "template-devnet-0"
}

variable "base_cidr_block" {
  default = "10.2.0.0/16"
}
////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  vm_groups = [
    var.bootnode,
    # Supernodes
    var.lighthouse_geth_super,
    var.lighthouse_nethermind_super,
    var.lighthouse_besu_super,
    var.lighthouse_erigon_super,
    var.lighthouse_reth_super,
    var.lighthouse_nimbusel_super,
    var.prysm_geth_super,
    var.prysm_nethermind_super,
    var.prysm_besu_super,
    var.prysm_erigon_super,
    var.prysm_reth_super,
    var.prysm_nimbusel_super,
    var.teku_geth_super,
    var.teku_nethermind_super,
    var.teku_besu_super,
    var.teku_erigon_super,
    var.teku_reth_super,
    var.teku_nimbusel_super,
    var.nimbus_geth_super,
    var.nimbus_nethermind_super,
    var.nimbus_besu_super,
    var.nimbus_erigon_super,
    var.nimbus_reth_super,
    var.nimbus_nimbusel_super,
    var.lodestar_geth_super,
    var.lodestar_nethermind_super,
    var.lodestar_besu_super,
    var.lodestar_erigon_super,
    var.lodestar_reth_super,
    var.lodestar_nimbusel_super,
    var.grandine_geth_super,
    var.grandine_nethermind_super,
    var.grandine_besu_super,
    var.grandine_erigon_super,
    var.grandine_reth_super,
    var.grandine_nimbusel_super,
    # Fullnodes
    var.lighthouse_geth_full,
    var.lighthouse_nethermind_full,
    var.lighthouse_besu_full,
    var.lighthouse_erigon_full,
    var.lighthouse_reth_full,
    var.lighthouse_nimbusel_full,
    var.prysm_geth_full,
    var.prysm_nethermind_full,
    var.prysm_besu_full,
    var.prysm_erigon_full,
    var.prysm_reth_full,
    var.prysm_nimbusel_full,
    var.teku_geth_full,
    var.teku_nethermind_full,
    var.teku_besu_full,
    var.teku_erigon_full,
    var.teku_reth_full,
    var.teku_nimbusel_full,
    var.nimbus_geth_full,
    var.nimbus_nethermind_full,
    var.nimbus_besu_full,
    var.nimbus_erigon_full,
    var.nimbus_reth_full,
    var.nimbus_nimbusel_full,
    var.lodestar_geth_full,
    var.lodestar_nethermind_full,
    var.lodestar_besu_full,
    var.lodestar_erigon_full,
    var.lodestar_reth_full,
    var.lodestar_nimbusel_full,
    var.grandine_geth_full,
    var.grandine_nethermind_full,
    var.grandine_besu_full,
    var.grandine_erigon_full,
    var.grandine_reth_full,
    var.grandine_nimbusel_full,
  ]
}