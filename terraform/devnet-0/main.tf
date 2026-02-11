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

provider "hcloud" {
  token = var.hcloud_token
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "hcloud_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Hetzner Cloud API Token (optional if not using Hetzner)"
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
  # Normalize node entries with defaults and calculate starting index for continuous numbering
  nodes_normalized = [
    for idx, node in var.nodes : {
      name            = node.name
      count           = node.count
      cloud           = node.cloud
      validator_start = try(node.validator_start, 0)
      validator_end   = try(node.validator_end, 0)
      size            = try(node.size, null)
      region          = try(node.region, null)
      location        = try(node.location, try(node.region, null))
      supernode       = try(node.supernode, null)
      ipv6            = try(node.ipv6, true)
      ipv4_enabled    = try(node.ipv4_enabled, true)
      ipv6_enabled    = try(node.ipv6_enabled, true)
      # Calculate starting index: sum of counts from all previous entries with same name
      start_index = sum([for i, n in var.nodes : n.count if i < idx && n.name == node.name])
    }
  ]

  # Filter by cloud provider (only nodes with count > 0)
  digitalocean_nodes = [for n in local.nodes_normalized : n if n.cloud == "digitalocean" && n.count > 0]
  hetzner_nodes      = [for n in local.nodes_normalized : n if n.cloud == "hetzner" && n.count > 0]
}
