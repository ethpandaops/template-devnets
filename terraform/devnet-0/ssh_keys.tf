////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "coredevs_api_url" {
  type    = string
  default = "https://coredevs.analytics.production.platform.ethpandaops.io"
}

variable "root_authorized_keys_github_team" {
  type    = string
  default = "ethpandaops"
}

variable "root_authorized_keys_github_extra_users" {
  type    = list(string)
  default = []
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        DATA SOURCES
////////////////////////////////////////////////////////////////////////////////////////
data "http" "root_github_users" {
  url = "${var.coredevs_api_url}/api/v1/users/${var.root_authorized_keys_github_team}?format=txt"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Fetching the ${var.root_authorized_keys_github_team} team members returned HTTP ${self.status_code}"
    }
  }
}

data "http" "root_github_keys" {
  for_each = local.root_github_users
  url      = "https://github.com/${each.key}.keys"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Fetching the SSH keys of ${each.key} returned HTTP ${self.status_code}"
    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  root_github_users = toset(concat(
    compact([for user in split("\n", data.http.root_github_users.response_body) : trimspace(user)]),
    var.root_authorized_keys_github_extra_users
  ))

  root_authorized_keys = distinct(compact(flatten([
    for user in sort(local.root_github_users) : [
      for key in split("\n", data.http.root_github_keys[user].response_body) : trimspace(key)
    ]
  ])))

  root_user_data = "#cloud-config\n${yamlencode({ ssh_authorized_keys = local.root_authorized_keys })}"
}
