#!/usr/bin/env bash
# Round-trip check of deployed validator key ranges, without ansible.
#
# Reads every node's <validator datadir>/.validator_keyrange marker over plain
# ssh and compares it against validator_start/validator_end in the inventory.
# Deliberately NOT an ansible playbook: templating hostvars (sops + group_vars)
# for 1000 hosts burns minutes of CPU, while 1000 `ssh sudo cat` round trips
# at 30 in parallel finish in about a minute at near-zero local load.
#
# Usage: scripts/check-validator-ranges.sh [devnet-N | inventory.ini] [parallelism]
#   no arg        current devnet from ansible.cfg's `inventory =` line
#   devnet-N      that devnet's inventory (ansible/inventories/devnet-N/inventory.ini)
#   <path>        an inventory file, used as-is
# Prints one line per host ("<host> OK" or "<host> PROBLEM deployed=... expected=...")
# and a summary; exits non-zero if any host is not OK.
#
# Assumes: ssh as the ansible user (devops) with passwordless sudo, and the
# hostname's first dash-separated token naming the CL client (the validator
# datadir is /data/<client>-validator across all client group_vars).
set -euo pipefail

ansible_dir=$(cd "$(dirname "$0")/../ansible" && pwd)
parallel=${2:-30}

if [ $# -ge 1 ] && [ -f "$1" ]; then
  inventory=$1
elif [ $# -ge 1 ]; then
  case "$1" in
    */*|*.ini) inventory=$1 ;;  # looks like a path: report it as given
    *)         inventory="$ansible_dir/inventories/$1/inventory.ini" ;;
  esac
else
  # The devnet ansible.cfg points `inventory =` at the current devnet
  # (relative to the ansible dir).
  cfg_inventory=$(awk -F= '$1 ~ /^inventory[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$ansible_dir/ansible.cfg")
  [ -n "$cfg_inventory" ] || { echo "no 'inventory =' line in $ansible_dir/ansible.cfg" >&2; exit 1; }
  case "$cfg_inventory" in
    /*) inventory=$cfg_inventory ;;
    *)  inventory="$ansible_dir/$cfg_inventory" ;;
  esac
fi

[ -f "$inventory" ] || { echo "inventory not found: $inventory (pass devnet-N or an inventory file)" >&2; exit 1; }
echo "inventory: $inventory"
results=$(mktemp)
trap 'rm -f "$results"' EXIT

# macOS has no `timeout` unless coreutils is installed (gtimeout); fall back to
# nothing — the ServerAlive options below still bound a hung session on their own.
TIMEOUT_CMD=""
for t in timeout gtimeout; do
  if command -v "$t" >/dev/null 2>&1; then TIMEOUT_CMD="$t 20"; break; fi
done
export TIMEOUT_CMD

check() {
  local host=$1 ip=$2 client=$3 exp=$4 got
  got=$($TIMEOUT_CMD ssh -o BatchMode=yes -o ConnectTimeout=8 \
        -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
        "devops@$ip" \
        "sudo cat /data/${client}-validator/.validator_keyrange 2>/dev/null || echo MISSING" \
        2>/dev/null) || got=UNREACHABLE
  if [ "$got" = "$exp" ]; then
    echo "$host OK"
  else
    echo "$host PROBLEM deployed=$got expected=$exp"
  fi
}
export -f check

awk '/ansible_host=/ && /validator_start=/ {
  host=$1; ip=""; vs=""; ve="";
  for(i=2;i<=NF;i++){
    if($i ~ /^ansible_host=/){split($i,a,"=");ip=a[2]}
    if($i ~ /^validator_start=/){split($i,a,"=");vs=a[2]}
    if($i ~ /^validator_end=/){split($i,a,"=");ve=a[2]}
  }
  split(host,h,"-"); print host, ip, h[1], vs"-"ve
}' "$inventory" | sort -u \
  | xargs -P "$parallel" -n 4 bash -c 'check "$@"' _ > "$results"

sort "$results"
# BSD wc pads its output with spaces; tr keeps the numbers clean on macOS.
total=$(wc -l < "$results" | tr -d '[:space:]')
ok=$(grep -c " OK$" "$results" || true)
echo "---"
echo "total=$total ok=$ok problems=$((total - ok))"
[ "$ok" -eq "$total" ]
