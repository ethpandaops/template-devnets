#!/usr/bin/env zsh
node="bootnode-1"
network="devnet-0"
domain="ethpandaops.io"
srv="srv"
prefix="template"
sops_name=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_nginx_shared_basic_auth.name')
sops_password=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_nginx_shared_basic_auth.password')
sops_mnemonic=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_genesis_mnemonic')
rpc_prefix=$(yq -r '.ethereum_node_rpc_prefix' ../ansible/inventories/$network/group_vars/all/all.yaml)
rpc_endpoint="${RPC_ENDPOINT:-https://$sops_name:$sops_password@rpc.$node.$prefix-$network.$domain}"
beacon_prefix=$(yq -r '.ethereum_node_beacon_prefix' ../ansible/inventories/$network/group_vars/all/all.yaml)
bn_endpoint="${BEACON_ENDPOINT:-https://$sops_name:$sops_password@$beacon_prefix$node.$srv.$prefix-$network.$domain}"
rpc_endpoint="${RPC_ENDPOINT:-https://$sops_name:$sops_password@$rpc_prefix$node.$srv.$prefix-$network.$domain}"
bootnode_endpoint="${BOOTNODE_ENDPOINT:-https://bootnode-1.$prefix-$network.$domain}"
assertoor_endpoint="${ASSERTOOR_ENDPOINT:-https://assertoor.$prefix-$network.$domain}"
auth_endpoint="${AUTH_ENDPOINT:-https://auth.$prefix-$network.$domain}"
slashing_test_id="validator-slashing-single"
slashing_playbook="${ASSERTOOR_SLASHING_PLAYBOOK:-https://raw.githubusercontent.com/ethpandaops/assertoor/master/playbooks/dev/$slashing_test_id.yaml}"

# Verify every external tool run.zsh depends on is installed.
# Pass 1 to print every tool; pass 0 (or empty) to print only missing tools.
check_deps() {
  local verbose="$1"
  local tools=(sops yq curl jq awk bc python3 docker cast ethdo ethereal eth2-val-tools)
  local os
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux)  os="linux" ;;
    *)      os="other" ;;
  esac
  typeset -A hints
  if [[ "$os" == "macos" ]]; then
    hints[sops]="brew install sops"
    hints[yq]="brew install yq"
    hints[curl]="preinstalled on macOS"
    hints[jq]="brew install jq"
    hints[awk]="preinstalled on macOS"
    hints[bc]="preinstalled on macOS"
    hints[python3]="preinstalled on macOS (or: brew install python)"
    hints[docker]="https://docs.docker.com/desktop/install/mac-install/"
  else
    hints[sops]="apt install sops  # or download from https://github.com/getsops/sops/releases"
    hints[yq]="apt install yq  # or download from https://github.com/mikefarah/yq/releases"
    hints[curl]="apt install curl"
    hints[jq]="apt install jq"
    hints[awk]="apt install gawk"
    hints[bc]="apt install bc"
    hints[python3]="apt install python3"
    hints[docker]="https://docs.docker.com/engine/install/"
  fi
  hints[cast]="curl -L https://foundry.paradigm.xyz | bash && foundryup"
  hints[ethdo]="go install github.com/wealdtech/ethdo@latest"
  hints[ethereal]="go install github.com/wealdtech/ethereal/v2@latest"
  hints[eth2-val-tools]="go install github.com/protolambda/eth2-val-tools@latest"

  local missing=0
  [[ "$verbose" == "1" ]] && { echo "Checking dependencies for run.zsh..."; echo "" }
  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      [[ "$verbose" == "1" ]] && printf "  \033[32m✓\033[0m %s\n" "$tool"
    else
      printf "  \033[31m✗\033[0m %s — install: %s\n" "$tool" "${hints[$tool]}" >&2
      missing=$((missing + 1))
    fi
  done
  if [[ $missing -eq 0 ]]; then
    [[ "$verbose" == "1" ]] && { echo ""; echo "All dependencies present." }
    return 0
  fi
  echo "" >&2
  echo "$missing tool(s) missing. Install them and retry." >&2
  return 1
}

# Mint a JWT for the assertoor API. The assertoor API (POST endpoints)
# requires a Bearer token issued by the devnet auth provider, which is itself
# gated by Cloudflare Access. A CF Access service token
# (CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET) gets us through CF Access to
# /auth/token, which returns the JWT assertoor accepts. Set ASSERTOOR_TOKEN
# directly to skip the exchange (e.g. a token you minted by hand).
get_assertoor_token() {
  if [[ -n "$ASSERTOOR_TOKEN" ]]; then
    echo "$ASSERTOOR_TOKEN"
    return 0
  fi

  # The minted JWT is valid for ~30 minutes, so cache it (owner-only) and
  # reuse it across runs while it still has more than 60s of life left,
  # rather than hitting the auth provider on every invocation.
  local cache="${TMPDIR:-/tmp}/.assertoor_token_${prefix}-${network}.json"
  if [[ -f "$cache" ]]; then
    local cached_tok cached_exp
    cached_tok=$(jq -r '.token // empty' "$cache" 2>/dev/null)
    cached_exp=$(jq -r '.expr // 0' "$cache" 2>/dev/null)
    if [[ -n "$cached_tok" ]] && (( cached_exp > $(date +%s) + 60 )); then
      echo "$cached_tok"
      return 0
    fi
  fi

  if [[ -z "$CF_ACCESS_CLIENT_ID" || -z "$CF_ACCESS_CLIENT_SECRET" ]]; then
    echo "Assertoor API requires authentication and no cached token is valid." >&2
    echo "Set a Cloudflare Access service token:" >&2
    echo "  export CF_ACCESS_CLIENT_ID=...    CF_ACCESS_CLIENT_SECRET=..." >&2
    echo "or provide a ready JWT directly: export ASSERTOOR_TOKEN=..." >&2
    return 1
  fi

  # Reject obviously malformed creds early (a common mistake is exporting the
  # whole 'CF-Access-Client-Id: <id>' header line instead of just the value).
  if [[ "$CF_ACCESS_CLIENT_ID" != *.access || "$CF_ACCESS_CLIENT_ID" == *[[:space:]]* ]]; then
    echo "CF_ACCESS_CLIENT_ID does not look like a CF Access client id (expected '<id>.access', no spaces)." >&2
    echo "Got: '${CF_ACCESS_CLIENT_ID}'" >&2
    return 1
  fi

  local body http_code tok
  body=$(curl -s -w $'\n%{http_code}' "$auth_endpoint/auth/token" \
    -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
    -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET")
  http_code=${body##*$'\n'}
  body=${body%$'\n'*}

  # Cloudflare Access bounces unauthorized service tokens with a 3xx to its
  # own login page instead of passing through to /auth/token. A 401/403 means
  # the same. Either way the token is not accepted for this Access app.
  if [[ "$http_code" == 3* || "$http_code" == "401" || "$http_code" == "403" ]]; then
    echo "Cloudflare Access rejected the service token at $auth_endpoint (HTTP $http_code)." >&2
    echo "This CF Access token is not authorized for the auth app — add it to that" >&2
    echo "application's CF Access 'Service Auth' policy, or export a different token." >&2
    return 1
  fi
  if [[ "$http_code" != "200" ]]; then
    echo "Unexpected response from $auth_endpoint/auth/token (HTTP $http_code):" >&2
    echo "${body:0:300}" >&2
    return 1
  fi

  tok=$(echo "$body" | jq -r '.token // empty' 2>/dev/null)
  if [[ -z "$tok" ]]; then
    echo "Auth provider returned 200 but no token field:" >&2
    echo "${body:0:300}" >&2
    return 1
  fi
  (umask 077; echo "$body" > "$cache")
  echo "$tok"
}

# Expand a comma-separated list of validator indices and inclusive ranges
# ("5", "1,2,3", "1..10") into one index per line.
expand_validator_indices() {
  local token n range_start range_end
  for token in ${(s:,:)1}; do
    if [[ "$token" =~ ^[0-9]+\.\.[0-9]+$ ]]; then
      range_start=${token%%..*}
      range_end=${token##*..}
      if (( range_start > range_end )); then
        echo "Error: invalid range '$token' (start > end)." >&2
        return 1
      fi
      for ((n=range_start; n<=range_end; n++)); do
        echo "$n"
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      echo "$token"
    else
      echo "Error: '$token' is not a valid validator index or range." >&2
      return 1
    fi
  done
}

# Helper function to display available options
print_usage() {
  echo "Usage:"
  echo "  ./run.zsh [command]"
  echo
  echo "Available commands:"
  echo "  check_deps                        Verify every external tool this script depends on is installed"
  echo "  consolidate indices               Self-consolidate: switch validators from 0x01 to 0x02 compounding withdrawal credentials"
  echo "  consolidate sources target        Consolidate one or more source validators into a target (EIP-7251). sources: 5 | 1,2,3 | 1..10 (inclusive range)"
  echo "  deposit s e [type]                Deposit to the network from validator index start to end - optional withdrawal type (0x00, 0x01, 0x02)"
  echo "  epoch_summary n                   Get the epoch summary for epoch n [default current - 1 epoch]"
  echo "  exit s e                          Exit from the network from validator index start to end - mandatory argument"
  echo "  finalized_epoch                   Get the finalized epoch"
  echo "  finalized_slot                    Get the finalized slot"
  echo "  finalized_slot_exec_payload       Get the finalized slot execution payload"
  echo "  finalized_slot_verbose            Get the finalized slot with verbose output"
  echo "  fork_choice                       Get the fork choice of the network"
  echo "  full_withdrawal s e               Withdraw from the network from validator index start to end - mandatory argument"
  echo "  genesis                           Get the genesis block"
  echo "  get_balance address               Get the balance of address - mandatory argument"
  echo "  get_beacon                        Get the beacon of the network"
  echo "  get_block n                       Get the block number n [default latest]"
  echo "  get_block_for_slot n              Get the block for a given slot - mandatory argument"
  echo "  get_enodes                        Get the enodes of the network"
  echo "  get_enrs                          Get the ENRs of the network"
  echo "  get_inventory                     Get the inventory of the network"
  echo "  get_peerid                        Get the peerid of the network"
  echo "  get_rpc                           Get the rpc of the network"
  echo "  get_slot n                        Get the slot number n [default head]"
  echo "  get_slot_for_blob txhash          Get the slot for a given blob given txhash, or send blob now"
  echo "  get_slot_for_blob_verbose txhash  Get the slot for a given blob with verbose output given txhash, or send blob now"
  echo "  help                              Print this help message"
  echo "  latest_block                      Get the latest block"
  echo "  latest_root                       Get the latest root"
  echo "  latest_slot                       Get the latest slot"
  echo "  latest_slot_verbose               Get the latest slot with verbose output"
  echo "  send_blob n                       Send "n" number of blob(s) to the network [default 1]"
  echo "  send_funds address amount         Send ETH to an address - amount in ETH"
  echo "  set_withdrawal_addr s e address   Set the withdrawal credentials for validator index start (mandatory) to end (optional) and Ethereum address"
  echo "  slash index|start..end            Slash a validator (or inclusive range) via the assertoor proposer-slashing playbook"
  echo "  sync_mapping [src] [pending]      Extend validator_names.yaml with post-genesis mnemonic deposits found on the beacon node (src default: main-mnemonic)."
  echo "                                    With 'pending', additionally map the still-queued pending_deposits in one shot: verifies the FIFO queue is strictly"
  echo "                                    sequential for this mnemonic (no foreign entries; duplicates are top-ups only) and appends the full future range."
  echo "  topup indices eth_amount          Top-up one or more validators with additional ETH (Pectra). indices: 5 | 1,2,3 | 1..10 (inclusive range)"
  echo "  validators                        Get the validator ranges"
  echo "  whose_validator_for_slot n        Get the validator for a given slot "n" - mandatory argument"
  echo ""
  echo " To use an alternative endpoint run the script by setting the environment variable:"
  echo "    BEACON_ENDPOINT=https://bn.alternative.beacon.endpoint \\"
  echo "    RPC_ENDPOINT=https://rpc.alternative.rpc.endpoint \\"
  echo "    BOOTNODE_ENDPOINT=https://bootnode.alternative.endpoint \\"
  echo "    ./run.zsh [command]"
  echo
}

# Store the command in an array
command=("$@")

# Check if no command are provided
if [[ $# -eq 0 ]]; then
  echo "Please provide at least one argument."
  print_usage
  exit 1
fi

# Loop through each argument
for arg in "${command[@]}"; do
  case $arg in
    "genesis")
      # Get the genesis block of the network
      genesis=$(curl -s $bn_endpoint/eth/v1/beacon/genesis | jq .data)
      echo "Genesis Block: $genesis"
      ;;
    "validators")
      # Get the validators of the network
      validators=$(curl -s $bootnode_endpoint/meta/api/v1/validator-ranges.json | jq .ranges)
      echo "Validator ranges: $validators"
      ;;
    "sync_mapping")
      # Extend the validator names mapping with post-genesis deposits made from
      # the genesis mnemonic. Reads the current mapping, fetches the on-chain
      # validator set from the beacon node, matches newly-deposited validators
      # back to the mnemonic by deriving its pubkeys, and appends the new index
      # ranges. Re-running is idempotent: once added, ranges advance past them.
      # With a trailing 'pending' argument it also maps the NOT-yet-processed
      # pending_deposits queue in one shot: the queue is FIFO, so if its first
      # occurrences continue this mnemonic's key sequence with no foreign
      # entries (duplicates = top-ups only), the future on-chain indices are
      # already determined and one full-range entry can be written up front.
      src_name="${command[2]:-main-mnemonic}"
      include_pending="${command[3]:-}"
      mapping_file="../network-configs/$network/metadata/validator_names.yaml"

      if [[ ! -f "$mapping_file" ]]; then
        echo "Mapping file not found: $mapping_file" >&2
        exit 1
      fi

      # YAML -> JSON, tolerant of both mikefarah (-o=json) and python-yq (-c) yq.
      if yq --version 2>&1 | grep -qi mikefarah; then
        mapping_json=$(yq -o=json -I=0 '.' "$mapping_file")
      else
        mapping_json=$(yq -c '.' "$mapping_file")
      fi

      # Next free mnemonic key index for this source, and next free on-chain index.
      next_key=$(echo "$mapping_json" | jq --arg src "$src_name" \
        '[ .[] | to_entries[] | select(.value.src == $src) | .value.to ] | (max // -1) + 1')
      next_state=$(echo "$mapping_json" | jq \
        '[ .[] | to_entries[] | (.key | tostring | split("-")[1] | tonumber) ] | (max // -1) + 1')

      echo "Syncing '$src_name' mapping (next on-chain index: $next_state, next key index: $next_key)"

      # The validator set and derived key map can be large (thousands of
      # entries), so they are exchanged with jq via files (--slurpfile) instead
      # of command-line args, which would overflow the argument list.
      sync_tmp=$(mktemp -d)

      # Fetch the full validator set from the beacon node in a single request and
      # keep the validators beyond the last mapped index (index >= next_state).
      curl -s "$bn_endpoint/eth/v1/beacon/states/head/validators" \
        | jq -c --argjson min "$next_state" \
          '[ .data[] | {index: (.index | tonumber), pubkey: .validator.pubkey} | select(.index >= $min) ]' \
        > "$sync_tmp/new.json"

      new_count=$(jq 'length' "$sync_tmp/new.json")
      if [[ "$new_count" == "0" && -z "$include_pending" ]]; then
        rm -rf "$sync_tmp"
        echo "No on-chain validators beyond index $((next_state - 1)); mapping is up to date."
        exit 0
      fi
      echo "Found $new_count new on-chain validator(s); matching against the mnemonic..."

      # Derive the mnemonic's pubkeys for the next key indices (at most as many as
      # there are new validators) into a pubkey -> key-index lookup.
      eth2-val-tools pubkeys \
        --source-min=$next_key --source-max=$((next_key + new_count)) \
        --validators-mnemonic="$sops_mnemonic" \
        | jq -R -s --argjson base $next_key \
          '[ split("\n")[] | select(length > 0) ] | to_entries
           | map({key: (.value | ascii_downcase), value: ($base + .key)}) | from_entries' \
        > "$sync_tmp/derived.json"

      # Match new validators to the mnemonic by pubkey and collapse runs where the
      # on-chain index and the key index both advance by one into single entries.
      new_lines=$(jq -rn \
        --slurpfile new "$sync_tmp/new.json" \
        --slurpfile derived "$sync_tmp/derived.json" \
        --arg src "$src_name" '
        ($new[0]) as $vals
        | ($derived[0]) as $keymap
        | ( $vals
            | map(. as $v | ($v.pubkey | ascii_downcase) as $pk
                  | select($keymap | has($pk))
                  | {state: $v.index, key: $keymap[$pk]})
            | sort_by(.state) ) as $pairs
        | reduce $pairs[] as $p ([];
            if (length > 0) and (.[-1].state_to + 1 == $p.state) and (.[-1].key_to + 1 == $p.key)
            then .[:-1] + [ .[-1] + {state_to: $p.state, key_to: $p.key} ]
            else . + [ {state_from: $p.state, state_to: $p.state, key_from: $p.key, key_to: $p.key} ]
            end)
        | .[] | "- \(.state_from)-\(.state_to): { src: \"\($src)\", from: \(.key_from), to: \(.key_to) }"
      ')

      if [[ -z "$new_lines" && -z "$include_pending" ]]; then
        rm -rf "$sync_tmp"
        echo "None of the $new_count new validator(s) were derived from '$src_name'; nothing to add."
        exit 0
      fi

      # One-shot mapping of the still-queued pending_deposits. Safe because the
      # queue is processed strictly FIFO: if every first-occurrence pubkey in
      # queue order continues this mnemonic's key sequence (next_key, next_key+1,
      # ...) with no foreign pubkeys, the on-chain index of each future validator
      # is already (next_state + offset). Duplicates are tolerated only as
      # top-ups: repeats of an earlier queued key or of an already-mapped key
      # (they add balance, never a validator). Anything else aborts unchanged.
      pending_line=""
      if [[ -n "$include_pending" ]]; then
        if [[ "$include_pending" != "pending" ]]; then
          echo "Unknown sync_mapping option '$include_pending' (expected 'pending')." >&2
          rm -rf "$sync_tmp"; exit 1
        fi
        # Key/state cursors advanced past the in-state matches from this run.
        instate_n=$(printf '%s\n' "$new_lines" | grep -c "src: \"$src_name\"" || true)
        [[ -z "$new_lines" ]] && instate_n=0
        pend_key=$next_key
        pend_state=$next_state
        if [[ "$instate_n" -gt 0 ]]; then
          pend_key=$(printf '%s\n' "$new_lines" | tail -1 | sed -E 's/.*to: ([0-9]+).*/\1/')
          pend_key=$((pend_key + 1))
          pend_state=$(printf '%s\n' "$new_lines" | tail -1 | sed -E 's/^- [0-9]+-([0-9]+):.*/\1/')
          pend_state=$((pend_state + 1))
        fi

        curl -s "$bn_endpoint/eth/v1/beacon/states/head/pending_deposits" \
          | jq -c '[ .data[].pubkey | ascii_downcase ]' > "$sync_tmp/pending.json"
        pend_count=$(jq 'length' "$sync_tmp/pending.json")

        if [[ "$pend_count" == "0" ]]; then
          echo "Pending deposit queue is empty; nothing to pre-map."
        else
          # Derive from key 0 so duplicates of already-mapped keys are recognized.
          eth2-val-tools pubkeys \
            --source-min=0 --source-max=$((pend_key + pend_count)) \
            --validators-mnemonic="$sops_mnemonic" \
            | jq -R -s \
              '[ split("\n")[] | select(length > 0) ] | to_entries
               | map({key: (.value | ascii_downcase), value: .key}) | from_entries' \
            > "$sync_tmp/derived_all.json"

          pend_n=$(jq -n \
            --slurpfile q "$sync_tmp/pending.json" \
            --slurpfile d "$sync_tmp/derived_all.json" \
            --argjson base "$pend_key" '
            ($d[0]) as $keymap
            | reduce ($q[0])[] as $pk ({n: 0, seen: {}, ok: true};
                if .ok == false then .
                else ($keymap[$pk] // null) as $k
                | if $k == null then .ok = false                # foreign pubkey
                  elif $k < $base or .seen[($k|tostring)] then . # top-up duplicate
                  elif $k == $base + .n then .n += 1 | .seen[($k|tostring)] = true
                  else .ok = false                              # gap / out of order
                  end
                end)
            | if .ok then .n else -1 end')

          if [[ "$pend_n" == "-1" ]]; then
            echo "Pending queue is NOT strictly sequential for '$src_name' (foreign or out-of-order entries); not pre-mapping. Run plain sync_mapping as validators activate instead." >&2
            rm -rf "$sync_tmp"; exit 1
          elif [[ "$pend_n" == "0" ]]; then
            echo "Pending queue holds only top-ups of already-mapped keys; nothing to pre-map."
          else
            pending_line="- $pend_state-$((pend_state + pend_n - 1)): { src: \"$src_name\", from: $pend_key, to: $((pend_key + pend_n - 1)) }"
            echo "Pending queue verified FIFO-sequential ($pend_count entries -> $pend_n future validators; $((pend_count - pend_n)) top-up duplicates)."
          fi
        fi
      fi

      rm -rf "$sync_tmp"

      if [[ -z "$new_lines" && -z "$pending_line" ]]; then
        echo "Nothing to add; mapping is up to date."
        exit 0
      fi

      echo "Adding mapping entr(y/ies):"
      [[ -n "$new_lines" ]] && echo "$new_lines"
      [[ -n "$pending_line" ]] && echo "$pending_line"

      # Make sure the file ends with a newline before appending.
      [[ -n "$(tail -c1 "$mapping_file" 2>/dev/null)" ]] && printf '\n' >> "$mapping_file"
      [[ -n "$new_lines" ]] && printf '%s\n' "$new_lines" >> "$mapping_file"
      [[ -n "$pending_line" ]] && printf '%s\n' "$pending_line" >> "$mapping_file"
      echo "Updated $mapping_file"

      # Refresh the inventory web on the bootnode so it serves the new mapping.
      ( cd ../ansible && ansible-playbook -i "inventories/$network/inventory.ini" \
          --tags ethereum_inventory_web --limit bootnode playbook.yaml )

      # Roll Dora so it re-pulls the updated validator-names inventory.
      kubectl --context services -n "$prefix-$network" rollout restart deployment/dora

      # Commit ONLY the updated mapping to master. Passing the pathspec to
      # `git commit` makes a partial commit: it takes the working-tree content of
      # just this file and ignores the index, so any other modified or untracked
      # files in the tree are never swept into the commit.
      if git diff --quiet HEAD -- "$mapping_file"; then
        echo "No changes to $mapping_file to commit."
      elif git commit -m "$prefix-$network: sync validator_names.yaml" -- "$mapping_file"; then
        git push origin HEAD:master
      else
        echo "git commit failed; not pushing." >&2
        exit 1
      fi
      exit 0
      ;;
    "latest_root")
      # Get the latest root of the network
      latest_root=$(curl -s $bn_endpoint/eth/v1/beacon/states/head/root | jq .data.root)
      echo "Latest Root: $latest_root"
      ;;
    "latest_slot")
      # Get the latest slot of the network
      latest_slot=$(curl -s $bn_endpoint/eth/v1/beacon/headers/head | jq .)
      echo "Latest Slot: $latest_slot"\
      ;;
    "latest_slot_verbose")
      # Get the latest slot of the network
      latest_slot=$(ethdo --connection=$bn_endpoint block info --verbose )
      echo "Latest Slot: $latest_slot"
      ;;
    "latest_block")
      # Get the latest block of the network
      latest_block=$(curl -s --data-raw '{"jsonrpc":"2.0","method":"eth_getBlockByNumber", "params":["latest"], "id":0}' $rpc_endpoint | jq .)
      echo "Latest Block: $latest_block"
      ;;
    "get_slot")
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a slot number as the second argument, or get the latest slot"
        echo "  Example: ${0} get_slot 100"
        # since none is provided, get latest slot
        ${0} latest_slot
        exit;
      else
        slot=${command[2]}
        # Get the slot specified on the network
        get_slot=$(curl -s $bn_endpoint/eth/v2/beacon/blocks/${slot} | jq .)
        echo "$get_slot"
        exit;
      fi
      ;;
    "get_block")
      # Get a specific block of the network
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a block number as the second argument, or get the latest block"
        echo "  Example: ${0} get_block 100"
        ${0} latest_block
        exit;
      else
        block=${command[2]}
        hex_block=$(printf "%x\n" $block)
        get_block=$(curl -s --data-raw '{"jsonrpc":"2.0","method":"eth_getBlockByNumber", "params":["0x'${hex_block}'"], "id":0}' $rpc_endpoint | jq .)
        echo "Block $block: $get_block"
        exit;
      fi
      ;;
    "get_balance")
      # Get a specific block of the network
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a address as the second argument"
        echo "  Example: ${0} get_balance 0xf97e180c050e5ab072211ad2c213eb5aee4df134"
        exit;
      elif [[ (${#command[2]} == 42) && (${command[2]} == 0x*) ]]; then
        balance=$(curl -s  --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getBalance", "params":["'${command[2]}'","latest"], "id":0}' $rpc_endpoint | jq -r '.result' | python3 -c "import sys; print(int(sys.stdin.read(), 16) / 1e18)")
        echo "balance ${command[2]}: $balance Ether"
        exit;
      else
        echo "You did not provide a valid address as the second argument"
        echo "  Example: ${0} get_balance 0xf97e180c050e5ab072211ad2c213eb5aee4df134"
        exit;
      fi
      ;;
    "finalized_epoch")
      # Get the finalized slot of the network
      finalized_epoch=$(ethdo --connection=$bn_endpoint chain status --verbose | awk '/Finalized epoch:/{print $NF}')
      echo "Finalized epoch: $finalized_epoch"
      ;;
    "finalized_slot")
      # Get the finalized slot of the network
      finalized_epoch=$(ethdo --connection=$bn_endpoint chain status --verbose | awk '/Finalized epoch:/{print $NF}')
      finalized_slotnum=$((finalized_epoch * 32))
      echo "Finalized slot: $finalized_slotnum"
      ;;
    "finalized_slot_verbose")
      # Get the finalized slot of the network
      finalized_epoch=$(ethdo --connection=$bn_endpoint chain status --verbose | awk '/Finalized epoch:/{print $NF}')
      finalized_slotnum=$((finalized_epoch * 32))
      block_info=$(ethdo --connection=$bn_endpoint block info --blockid $finalized_slotnum --verbose)
      echo "Finalized slot:\n$block_info"
      ;;
    "finalized_slot_exec_payload")
      # Get the finalized slot of the network
      finalized_epoch=$(ethdo --connection=$bn_endpoint chain status --verbose | awk '/Finalized epoch:/{print $NF}')
      finalized_slotnum=$((finalized_epoch * 32))
      block_info=$(ethdo --connection=$bn_endpoint block info --blockid $finalized_slotnum --verbose)
      execution_payload=$(echo "$block_info" | awk '/Execution payload/ {flag=1; next} flag && /^[[:blank:]]+/ {print}')
      echo "Finalized slot exec payload:\n$execution_payload"
      ;;
    "epoch_summary")
      # Get the epoch summary of the network
      #if second arg is not provided, get the current - 1 epoch, else query the specific epoch
      if [[ -z "${command[2]}" ]]; then
        current_epoch=$(ethdo --connection=$bn_endpoint epoch summary | awk -F'[: ]' '/Epoch/{print $2}')
        last_epoch=$((current_epoch - 1))
        echo "Last epoch: $last_epoch"
        epoch_summary=$(ethdo --connection=$bn_endpoint epoch summary --epoch $last_epoch)
        echo "Epoch Summary: $epoch_summary"
      else
        epoch_summary=$(ethdo --connection=$bn_endpoint epoch summary --epoch ${command[2]})
        echo "Epoch Summary: $epoch_summary"
        exit;
      fi
      ;;
    "get_slot_for_blob")
      # Get the slot for a given blob
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a blob tx hash as the second argument or send a blob now"
        echo "Would you like to send a blob right now? (y/n)"
        read -r response
        if [[ $response == y ]]
        then
          echo "Sending single blob to the network"
          blob_hash=$(${0} send_blob 1 | awk '/Result:/{print $NF}' | awk -F ':' '{print $2}')
          echo $blob_hash
          echo "Waiting for blob to be included in a block (sleeping 30 seconds)"
          sleep 30
          ${0} get_slot_for_blob $blob_hash
          exit;
        else
          echo "Exiting without sending a blob to the network"
          exit;
        fi
        exit;
      else
        blob=${command[2]}
        block_hash=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["'$blob'"],"id":0}' $rpc_endpoint | jq .result.blockHash)
        get_block_timestamp=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_getBlockByHash","params":['$block_hash',false],"id":0}' $rpc_endpoint| jq -r .result.timestamp )
        slot=$(ethdo --connection=$bn_endpoint block info --block-time=$get_block_timestamp | awk '/Slot/{print $NF}')
        echo "Slot for blob $blob: $slot"
        exit;
      fi
      ;;
    "get_slot_for_blob_verbose")
      # Get the slot for a given blob
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a blob tx hash as the second argument or send a blob now"
        echo "Would you like to send a blob right now? (y/n)"
        read -r response
        if [[ $response == y ]]
        then
          echo "Sending single blob to the network"
          blob_hash=$(${0} send_blob 1 | awk '/Result:/{print $NF}' | awk -F ':' '{print $2}')
          echo "Waiting for blob to be included in a block (sleeping 30 seconds)"
          sleep 30
          ${0} get_slot_for_blob_verbose $blob_hash
          exit;
        else
          echo "Exiting without sending a blob to the network"
          exit;
        fi
        exit;
      else
        blob=${command[2]}
        block_hash=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["'$blob'"],"id":0}' $rpc_endpoint | jq .result.blockHash)
        get_block_timestamp=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_getBlockByHash","params":['$block_hash',false],"id":0}' $rpc_endpoint | jq -r .result.timestamp)
        slot=$(ethdo --connection=$bn_endpoint block info --block-time=$get_block_timestamp)
        echo "Slot for blob $blob: $slot"
        exit;
      fi
      ;;
    "get_block_for_slot")
      # Get the block for a given slot
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a slot number as the second argument"
        echo "  Example: ${0} get_block_for_slot 100"
        exit;
      else
        slot=${command[2]}
        block_number=$(curl -s $bn_endpoint/eth/v2/beacon/blocks/$slot | jq -r '.data.message.body.execution_payload.block_number' )
        if [[ $block_number == null ]]; then
          echo "Block for slot $slot has not been produced"
          echo "Would you like to look for the next block? (y/n)"
          read -r response
          if [[ $response == y ]]
          then
            slot=$((slot + 1))
            echo "Looking for the next block for slot $slot"
            ${0} get_block_for_slot $slot
            exit;
          else
            echo "Exiting without looking for the next block"
            exit;
          fi
          exit;
        fi
        echo "Block is $block_number for slot $slot"
        exit;
      fi
      ;;
    "whose_validator_for_slot")
      # Get validator for specific slot
      if [[ -z "${command[2]}" ]]; then
        echo "Please provide a slot number as the second argument"
        echo "  Example: ${0} whose_validator_for_slot 100"
        exit;
      else
        slot=${command[2]}
        proposer_index=$(ethdo --connection=$bn_endpoint proposer duties --slot=$slot | grep -oE '[0-9]+')
        curl -s $bootnode_endpoint/meta/api/v1/validator-ranges.json | jq .ranges | jq -r 'to_entries[] | "\(.key | split("-") | .[0]),\(.key | split("-") | .[1] | tonumber - 1),\(.value)"' > validator.csv
        declare -A validators
        while IFS="," read -r low high whose
        do
          for i in $(seq ${low} ${high})
          do
            validators["${i}"]="${whose}"
          done
        done < validator.csv
        echo ${validators["$proposer_index"]}
        rm validator.csv
        exit;
      fi
      ;;
    "get_enrs")
      # Get the ENRs of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[] | .consensus.enr'
      ;;
    "get_enodes")
      # Get the enodes of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[] | .execution.enode'
      ;;
    "get_peerid")
      # Get the peerid of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[] | .consensus.peer_id'
      ;;
    "get_rpc")
      # Get the rpc of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[] | .execution.rpc_uri'
      ;;
    "get_beacon")
      # Get the beacon of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[] | .consensus.beacon_uri'
      ;;
    "get_inventory")
      # Get the inventory of the network
      curl -s https://config.$network_subdomain/api/v1/nodes/inventory | jq -r '.ethereum_pairs[]'
      ;;
    "fork_choice")
      # Get the fork choice of the network
      curl -s $bn_endpoint/eth/v1/debug/fork_choice | jq '.fork_choice_nodes | .[-1]'
      ;;
    "send_blob")
      # Get a private key from a mnemonic
      privatekey=$(ethereal hd keys --path="m/44'/60'/0'/0/7" --seed="$sops_mnemonic" | awk '/Private key/{print $NF}')
      if [[ -z "${command[2]}" ]]; then
        # sending only one blob
        echo "Sending a blob"
        blob=$(docker run --platform linux/x86_64 --rm ghcr.io/flcl42/send-blobs:latest $rpc_endpoint 1 "$privatekey" 0x000000000000000000000000000000000000f1c1 | awk '/Result:/{print $NF}' | awk -F ':' '{print $2}')
        echo "Blob submitted with hash $blob"
        echo "Would you like to check which slot the blob was included in? (y/n)"
        read -r response
        if [[ $response == y ]]
        then
          echo "Waiting for blob to be included in a block (sleeping 10 seconds)"
          sleep 10
          ${0} get_slot_for_blob $blob
          exit;
        fi
        exit;
      else
        echo "Sending ${command[2]} blobs"
        docker run --platform linux/x86_64 --rm ghcr.io/flcl42/send-blobs:latest $rpc_endpoint ${command[2]} "$privatekey" 0x000000000000000000000000000000000000f1c1
        exit;
      fi
      ;;
    "deposit")
      if [[ $# -lt 3 || $# -gt 6 ]]; then
        echo "Deposit calls for 3 to 6 arguments!"
        echo "  Usage: ${0} deposit startIndex endIndex [withdrawalType] [withdrawalAddress] [depositAmount]"
        echo ""
        echo "  Withdrawal types:"
        echo "    0x00 (default) - BLS withdrawal credentials"
        echo "    0x01          - Execution address withdrawal"
        echo "    0x02          - Custom execution address with amount"
        echo ""
        echo "  Examples:"
        echo "    ${0} deposit 0 10                                    # Default (0x00) - BLS withdrawal credentials"
        echo "    ${0} deposit 0 10 0x01                               # Execution address withdrawal (prompts for address)"
        echo "    ${0} deposit 0 10 0x01 0x742d35Cc...                 # Execution address withdrawal with address"
        echo "    ${0} deposit 0 10 0x02                               # Custom execution address with amount (prompts for both)"
        echo "    ${0} deposit 0 10 0x02 0x742d35Cc...                 # Custom execution address with amount (prompts for amount)"
        echo "    ${0} deposit 0 10 0x02 0x742d35Cc... 35              # Custom execution address with amount (35 ETH)"
        exit;
      else
        # Set default withdrawal type to 0x00 if not provided
        withdrawal_type=${command[4]:-"0x00"}

        # Handle different withdrawal types
        withdrawal_address=""
        deposit_amount="32000000000"

        case $withdrawal_type in
          "0x00")
            echo "Using default withdrawal credentials type: 0x00"
            ;;
          "0x01")
            echo "Using withdrawal credentials type: 0x01"
            # Check if withdrawal address is provided as argument
            if [[ -n "${command[5]}" ]]; then
              withdrawal_address="${command[5]}"
              echo "Using provided withdrawal address: $withdrawal_address"
            else
              echo "Please enter the withdrawal address:"
              read -r withdrawal_address
            fi
            if [[ ! $withdrawal_address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
              echo "Invalid withdrawal address format. Must be a valid Ethereum address."
              exit 1
            fi
            ;;
          "0x02")
            echo "Using withdrawal credentials type: 0x02"
            # Check if withdrawal address is provided as argument
            if [[ -n "${command[5]}" ]]; then
              withdrawal_address="${command[5]}"
              echo "Using provided withdrawal address: $withdrawal_address"
            else
              echo "Please enter the withdrawal address:"
              read -r withdrawal_address
            fi
            if [[ ! $withdrawal_address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
              echo "Invalid withdrawal address format. Must be a valid Ethereum address."
              exit 1
            fi
            # Check if deposit amount is provided as argument
            if [[ -n "${command[6]}" ]]; then
              deposit_amount_eth="${command[6]}"
              echo "Using provided deposit amount: $deposit_amount_eth ETH"
            else
              echo "Please enter the deposit amount in ETH (minimum 32 ETH):"
              read -r deposit_amount_eth
            fi
            if [[ $deposit_amount_eth -lt 32 ]]; then
              echo "Deposit amount must be at least 32 ETH."
              exit 1
            fi
            # Convert ETH to gwei (1 ETH = 1,000,000,000 gwei)
            deposit_amount=$((deposit_amount_eth * 1000000000))
            ;;
          *)
            echo "Invalid withdrawal type: $withdrawal_type"
            echo "Supported types: 0x00, 0x01, 0x02"
            exit 1
            ;;
        esac

        deposit_path="m/44'/60'/0'/0/7"
        privatekey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Private key/{print $NF}')
        publickey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Ethereum address/{print $NF}')
        fork_version=$(curl -s $bn_endpoint/eth/v1/beacon/genesis | jq -r '.data.genesis_fork_version')
        deposit_contract_address=$(curl -s $bn_endpoint/eth/v1/config/spec | jq -r '.data.DEPOSIT_CONTRACT_ADDRESS')

        # Build eth2-val-tools command based on withdrawal type
        if [[ $withdrawal_type == "0x00" ]]; then
          eth2-val-tools deposit-data --source-min=${command[2]} --source-max=${command[3]} --amount=$deposit_amount --fork-version=$fork_version --withdrawals-mnemonic="$sops_mnemonic" --validators-mnemonic="$sops_mnemonic" --withdrawal-credentials-type=$withdrawal_type > deposits_$prefix-$network-${command[2]}_${command[3]}.txt
        else
          eth2-val-tools deposit-data --source-min=${command[2]} --source-max=${command[3]} --amount=$deposit_amount --fork-version=$fork_version --withdrawals-mnemonic="$sops_mnemonic" --validators-mnemonic="$sops_mnemonic" --withdrawal-credentials-type=$withdrawal_type --withdrawal-address=$withdrawal_address > deposits_$prefix-$network-${command[2]}_${command[3]}.txt
        fi

        # Calculate total validators and total deposit amount
        total_validators=$((${command[3]} - ${command[2]}))
        total_deposit_gwei=$((total_validators * deposit_amount))
        total_deposit_eth=$((total_deposit_gwei / 1000000000))

        # ask if you want to deposit to the network
        echo "Are you sure you want to make a deposit to the network (${prefix}-${network})?"
        echo "  Validators: ${command[2]} to $((${command[3]} - 1)) ($total_validators validators)"
        echo "  Withdrawal type: $withdrawal_type"
        if [[ $withdrawal_type != "0x00" ]]; then
          echo "  Withdrawal address: $withdrawal_address"
        fi
        echo "  Deposit per validator: $((deposit_amount / 1000000000)) ETH"
        echo "  Total deposit: $total_deposit_eth ETH"
        echo ""
        echo "Continue? (y/n)"
        read -r response
        if [[ $response == "y" ]]; then
          nonce_hex=$(curl -s --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'$publickey'","pending"],"id":0}' $rpc_endpoint | jq -r '.result')
          nonce=$(( ${nonce_hex} ))
          deposit_eth=$((deposit_amount / 1000000000))

          echo "Starting nonce: $nonce | Deposit per validator: ${deposit_eth} ETH"

          tmpdir=$(mktemp -d)
          # zsh's background job table caps at 1024; batch so the active set stays well below.
          batch_size=500
          i=0
          while read x; do
            account_name="$(echo "$x" | jq -r '.account')"
            pubkey_val="0x$(echo "$x" | jq -r '.pubkey')"
            withdrawal_creds="0x$(echo "$x" | jq -r '.withdrawal_credentials')"
            signature_val="0x$(echo "$x" | jq -r '.signature')"
            data_root="0x$(echo "$x" | jq -r '.deposit_data_root')"
            echo "Sending deposit for validator $account_name (nonce: $((nonce + i)))"
            echo "$account_name" > "$tmpdir/cast-$i.name"
            cast send \
              --private-key "$privatekey" \
              --rpc-url "$rpc_endpoint" \
              --nonce $((nonce + i)) \
              --value "${deposit_eth}ether" \
              --gas-limit 2000000 \
              "$deposit_contract_address" \
              "deposit(bytes,bytes,bytes,bytes32)" \
              "$pubkey_val" "$withdrawal_creds" "$signature_val" "$data_root" > "$tmpdir/cast-$i.log" 2>&1 &
            i=$((i + 1))
            if (( i % batch_size == 0 )); then
              wait
              echo "Drained batch — $i submitted so far..."
            fi
          done < deposits_$prefix-$network-${command[2]}_${command[3]}.txt

          echo "Submitted $i deposits in batches of $batch_size, waiting for final batch..."
          wait
          echo ""
          ok=0
          fail=0
          for ((j=0; j<i; j++)); do
            log="$tmpdir/cast-$j.log"
            name=$(cat "$tmpdir/cast-$j.name" 2>/dev/null)
            txhash=$(grep -E '^transactionHash' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            tx_status=$(grep -E '^status' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            if [[ "$tx_status" == "1" ]]; then
              printf "  \033[32m✓\033[0m %s — %s\n" "$name" "$txhash"
              ok=$((ok + 1))
            else
              printf "  \033[31m✗\033[0m %s — failed (status=%s tx=%s)\n" \
                "$name" "${tx_status:-no-receipt}" "${txhash:-none}"
              grep -iE 'error|revert' "$log" 2>/dev/null | head -1 | sed 's/^/      /'
              fail=$((fail + 1))
            fi
          done
          echo ""
          echo "$ok confirmed, $fail failed (of $i submitted)"
          rm -rf "$tmpdir"
          exit;
        else
          echo "Exiting without depositing to the network"
          exit;
        fi
      fi
      ;;
    "send_funds")
      # Send ETH to an address
      if [[ $# -ne 3 ]]; then
        echo "Usage: ${0} send_funds <address> <amount_in_eth>"
        echo "  Example: ${0} send_funds 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18 10"
        exit 1
      fi
      to_address=${command[2]}
      eth_amount=${command[3]}
      if [[ ! $to_address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "Invalid address format. Must be a valid Ethereum address (0x + 40 hex chars)."
        exit 1
      fi
      if ! [[ "$eth_amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$eth_amount <= 0" | bc -l) )); then
        echo "Invalid amount. Must be a positive number."
        exit 1
      fi
      deposit_path="m/44'/60'/0'/0/7"
      privatekey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Private key/{print $NF}')
      publickey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Ethereum address/{print $NF}')
      balance=$(curl -s --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$publickey'","latest"],"id":0}' $rpc_endpoint | jq -r '.result' | python3 -c "import sys; print(int(sys.stdin.read(), 16) / 1e18)")
      echo "Sending $eth_amount ETH to $to_address"
      echo "  From: $publickey (balance: $balance ETH)"
      echo "  To: $to_address"
      echo "  Amount: $eth_amount ETH"
      echo ""
      echo "Continue? (y/n)"
      read -r response
      if [[ $response == "y" ]]; then
        cast send \
          --private-key "$privatekey" \
          --rpc-url "$rpc_endpoint" \
          --value "${eth_amount}ether" \
          --gas-limit 21000 \
          "$to_address"
        echo "Transaction sent!"
      else
        echo "Cancelled."
      fi
      exit
      ;;
    "topup")
      # Top-up one or more validators with additional ETH (Pectra upgrade feature)
      if [[ $# -ne 3 ]]; then
        echo "Top-up calls for exactly 2 arguments!"
        echo "  Usage: ${0} topup validator_index[,index2,...] eth_amount"
        echo "  Example: ${0} topup 5 35"
        echo "  Example: ${0} topup 1,2,3 10"
        echo "  Example: ${0} topup 1..10 10        # inclusive range, same as 1,2,...,10"
        exit;
      else
        validator_indices=${command[2]}
        eth_amount=${command[3]}

        # Validate ETH amount
        if ! [[ "$eth_amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$eth_amount < 1" | bc -l) )); then
          echo "Error: ETH amount must be >= 1."
          exit 1
        fi

        topup_indices=$(expand_validator_indices "$validator_indices") || exit 1
        VALIDATOR_ARRAY=("${(@f)topup_indices}")

        # Resolve each validator's pubkey from the beacon node.
        declare -a validator_pubkeys
        for validator_index in "${VALIDATOR_ARRAY[@]}"; do
          validator_info=$(curl -s "$bn_endpoint/eth/v1/beacon/states/head/validators/$validator_index")
          if [[ $(echo "$validator_info" | jq -r '.data') == "null" ]]; then
            echo "Error: Validator $validator_index not found."
            exit 1
          fi
          validator_pubkeys+=("$(echo "$validator_info" | jq -r '.data.validator.pubkey')")
        done

        # Get common info. We submit top-ups straight to the deposit contract via
        # `cast send` (like `deposit`) rather than `ethereal validator topup`:
        # ethereal ignores --nonce when online and can't run offline for topups, so
        # parallel ethereal calls all collide on one nonce. cast honours --nonce, so
        # each top-up gets its own and they can all broadcast at once.
        deposit_path="m/44'/60'/0'/0/7"
        privatekey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Private key/{print $NF}')
        publickey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Ethereum address/{print $NF}')
        deposit_contract_address=$(curl -s $bn_endpoint/eth/v1/config/spec | jq -r '.data.DEPOSIT_CONTRACT_ADDRESS')

        # A top-up is a deposit reusing an existing validator's pubkey. The consensus
        # layer ignores the withdrawal credentials and signature for an already-known
        # validator, so we send zeros for both; the execution-layer deposit contract
        # only checks that deposit_data_root matches the SSZ root of the deposit data.
        zero_wc="0x$(printf '0%.0s' {1..64})"
        zero_sig="0x$(printf '0%.0s' {1..192})"

        echo ""
        echo "Top-up Summary:"
        echo "  Validators: ${#VALIDATOR_ARRAY} validator(s)"
        if (( ${#VALIDATOR_ARRAY} <= 20 )); then
          for ((i=1; i<=${#VALIDATOR_ARRAY}; i++)); do
            echo "    ${VALIDATOR_ARRAY[$i]}: ${validator_pubkeys[$i]}"
          done
        else
          echo "    ${VALIDATOR_ARRAY[1]} .. ${VALIDATOR_ARRAY[-1]}"
        fi
        echo "  Amount per validator: $eth_amount ETH"
        echo "  Total amount: $(echo "${#VALIDATOR_ARRAY} * $eth_amount" | bc) ETH"
        echo "  Deposit Contract: $deposit_contract_address"
        echo ""
        echo "Continue? (y/n)"
        read -r response

        if [[ $response == "y" ]]; then
          tmpdir=$(mktemp -d)

          # Compute deposit_data_root for each validator locally (zero wc + zero sig).
          printf '%s\n' "${validator_pubkeys[@]}" > "$tmpdir/pubkeys.txt"
          python3 - "$eth_amount" "$tmpdir/pubkeys.txt" "$tmpdir/roots.txt" <<'PY'
import sys, hashlib
from decimal import Decimal
def h(b): return hashlib.sha256(b).digest()
amount_gwei = int(Decimal(sys.argv[1]) * (10**9))
wc = b'\x00'*32
sig = b'\x00'*96
sig_root = h(h(sig[0:64]) + h(sig[64:96] + b'\x00'*32))
amount_root = amount_gwei.to_bytes(8, 'little') + b'\x00'*24
out = []
with open(sys.argv[2]) as f:
    for line in f:
        pk = line.strip()
        if not pk:
            continue
        pub = bytes.fromhex(pk[2:] if pk.startswith('0x') else pk)
        pub_root = h(pub + b'\x00'*16)
        out.append('0x' + h(h(pub_root + wc) + h(amount_root + sig_root)).hex())
with open(sys.argv[3], 'w') as f:
    f.write('\n'.join(out) + '\n')
PY
          roots=("${(@f)$(cat "$tmpdir/roots.txt")}")

          # Fetch the nonce once and assign each top-up an explicit, incrementing
          # nonce so they can all be broadcast in parallel (same as `deposit`).
          nonce_hex=$(curl -s --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'$publickey'","pending"],"id":0}' $rpc_endpoint | jq -r '.result')
          nonce=$(( ${nonce_hex} ))
          echo "Starting nonce: $nonce | Top-up per validator: ${eth_amount} ETH"
          echo ""

          # zsh's background job table caps at 1024; batch so the active set stays well below.
          batch_size=500
          i=0
          for validator_index in "${VALIDATOR_ARRAY[@]}"; do
            validator_pubkey="${validator_pubkeys[$((i + 1))]}"
            data_root="${roots[$((i + 1))]}"
            echo "Sending top-up for validator $validator_index (nonce: $((nonce + i)))"
            echo "$validator_index" > "$tmpdir/cast-$i.name"
            cast send \
              --private-key "$privatekey" \
              --rpc-url "$rpc_endpoint" \
              --nonce $((nonce + i)) \
              --value "${eth_amount}ether" \
              --gas-limit 2000000 \
              "$deposit_contract_address" \
              "deposit(bytes,bytes,bytes,bytes32)" \
              "$validator_pubkey" "$zero_wc" "$zero_sig" "$data_root" > "$tmpdir/cast-$i.log" 2>&1 &
            i=$((i + 1))
            if (( i % batch_size == 0 )); then
              wait
              echo "Drained batch — $i submitted so far..."
            fi
          done

          echo "Submitted $i top-ups in batches of $batch_size, waiting for final batch..."
          wait
          echo ""
          ok=0
          fail=0
          for ((j=0; j<i; j++)); do
            log="$tmpdir/cast-$j.log"
            name=$(cat "$tmpdir/cast-$j.name" 2>/dev/null)
            txhash=$(grep -E '^transactionHash' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            tx_status=$(grep -E '^status' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            if [[ "$tx_status" == "1" ]]; then
              printf "  \033[32m✓\033[0m validator %s — %s\n" "$name" "$txhash"
              ok=$((ok + 1))
            else
              printf "  \033[31m✗\033[0m validator %s — failed (status=%s tx=%s)\n" \
                "$name" "${tx_status:-no-receipt}" "${txhash:-none}"
              grep -iE 'error|revert' "$log" 2>/dev/null | head -1 | sed 's/^/      /'
              fail=$((fail + 1))
            fi
          done
          echo ""
          echo "$ok confirmed, $fail failed (of $i submitted)"
          rm -rf "$tmpdir"
          exit;
        else
          echo "Top-up cancelled."
          exit;
        fi
      fi
      ;;
    "consolidate")
      # EIP-7251 consolidation requests. Two shapes:
      #   consolidate <sources> <target>  move the sources' balance into target
      #   consolidate <indices>           self-consolidation: 0x01 -> 0x02 credentials
      # Requests go to the consolidation predeploy and are only honoured when they
      # come from the source validator's own execution withdrawal address, so every
      # source in one run must share that address (it signs and pays the fee).
      if [[ $# -lt 2 || $# -gt 3 ]]; then
        echo "Consolidate calls for 1 or 2 arguments!"
        echo "  Usage: ${0} consolidate sourceIndex[,index2,...] targetIndex"
        echo "         ${0} consolidate validator_index[,index2,...]"
        echo "  Example: ${0} consolidate 5 6           # consolidate validator 5 into validator 6"
        echo "  Example: ${0} consolidate 1,2,3 10      # consolidate validators 1, 2 and 3 into validator 10"
        echo "  Example: ${0} consolidate 1..10 10      # inclusive range, same as 1,2,...,10"
        echo "  Example: ${0} consolidate 5             # self-consolidate: switch validator 5 to 0x02 credentials"
        echo "  Example: ${0} consolidate 1..10         # switch validators 1-10 to 0x02 compounding credentials"
        exit;
      else
        consolidation_contract="${CONSOLIDATION_CONTRACT:-0x0000BBdDc7CE488642fb579F8B00f3a590007251}"
        if [[ $# -eq 2 ]]; then
          consolidate_mode="self"
          source_spec="${command[2]}"
        else
          consolidate_mode="consolidate"
          source_spec="${command[2]}"
          target_index="${command[3]}"
          if [[ ! "$target_index" =~ ^[0-9]+$ ]]; then
            echo "Error: '$target_index' is not a valid target validator index."
            exit 1
          fi
        fi

        source_list=$(expand_validator_indices "$source_spec") || exit 1
        SOURCE_ARRAY=("${(@f)source_list}")

        if [[ "$(cast code "$consolidation_contract" --rpc-url "$rpc_endpoint" 2>/dev/null)" == "0x" ]]; then
          echo "Consolidation predeploy $consolidation_contract has no code on ${prefix}-${network}."
          exit 1
        fi

        spec=$(curl -s "$bn_endpoint/eth/v1/config/spec")
        slots_per_epoch=$(echo "$spec" | jq -r '.data.SLOTS_PER_EPOCH')
        shard_committee_period=$(echo "$spec" | jq -r '.data.SHARD_COMMITTEE_PERIOD')
        head_slot=$(curl -s "$bn_endpoint/eth/v1/beacon/headers/head" | jq -r '.data.header.message.slot')
        if [[ -z "$head_slot" || "$head_slot" == "null" || -z "$slots_per_epoch" || "$slots_per_epoch" == "null" ]]; then
          echo "Could not read the head slot / spec from $bn_endpoint."
          exit 1
        fi
        current_epoch=$((head_slot / slots_per_epoch))

        # Resolve every source: pubkey, withdrawal address and eligibility.
        declare -a source_indices source_pubkeys
        sender_address=""
        for validator_index in "${SOURCE_ARRAY[@]}"; do
          validator_info=$(curl -s "$bn_endpoint/eth/v1/beacon/states/head/validators/$validator_index")
          if [[ $(echo "$validator_info" | jq -r '.data') == "null" ]]; then
            echo "Error: Validator $validator_index not found."
            exit 1
          fi
          validator_pubkey=$(echo "$validator_info" | jq -r '.data.validator.pubkey')
          validator_creds=$(echo "$validator_info" | jq -r '.data.validator.withdrawal_credentials')
          validator_status=$(echo "$validator_info" | jq -r '.data.status')
          validator_activation=$(echo "$validator_info" | jq -r '.data.validator.activation_epoch')
          creds_type="${validator_creds:2:2}"

          if [[ "$creds_type" != "01" && "$creds_type" != "02" ]]; then
            echo "Error: validator $validator_index still has BLS (0x00) withdrawal credentials."
            echo "  Set an execution address first: ${0} set_withdrawal_addr $validator_index $validator_index <address>"
            exit 1
          fi
          if [[ "$consolidate_mode" == "self" && "$creds_type" == "02" ]]; then
            echo "Skipping validator $validator_index (already compounding, 0x02)."
            continue
          fi
          if [[ "$validator_status" != "active_ongoing" ]]; then
            echo "Error: validator $validator_index is $validator_status; consolidation requests are only honoured for active, non-exiting validators."
            exit 1
          fi
          # Only a real consolidation carries the SHARD_COMMITTEE_PERIOD wait;
          # a switch to compounding is valid from activation.
          if [[ "$consolidate_mode" == "consolidate" ]] && (( current_epoch < validator_activation + shard_committee_period )); then
            echo "Error: validator $validator_index activated at epoch $validator_activation; it can only be consolidated from epoch $((validator_activation + shard_committee_period)) (current: $current_epoch)."
            exit 1
          fi

          validator_address="0x${validator_creds:26}"
          if [[ -z "$sender_address" ]]; then
            sender_address="$validator_address"
          elif [[ "${validator_address:l}" != "${sender_address:l}" ]]; then
            echo "Error: validator $validator_index withdraws to $validator_address, earlier sources withdraw to $sender_address."
            echo "  Every source in one run must share a withdrawal address — split the run per address."
            exit 1
          fi

          source_indices+=("$validator_index")
          source_pubkeys+=("$validator_pubkey")
        done

        if (( ${#source_indices} == 0 )); then
          echo "Nothing to do."
          exit;
        fi

        if [[ "$consolidate_mode" == "consolidate" ]]; then
          if (( ${source_indices[(I)$target_index]} )); then
            echo "Error: validator $target_index is both a source and the target; use '${0} consolidate $target_index' for a self-consolidation."
            exit 1
          fi
          target_info=$(curl -s "$bn_endpoint/eth/v1/beacon/states/head/validators/$target_index")
          if [[ $(echo "$target_info" | jq -r '.data') == "null" ]]; then
            echo "Error: Target validator $target_index not found."
            exit 1
          fi
          target_pubkey=$(echo "$target_info" | jq -r '.data.validator.pubkey')
          target_creds=$(echo "$target_info" | jq -r '.data.validator.withdrawal_credentials')
          target_status=$(echo "$target_info" | jq -r '.data.status')
          # A consolidation target must already be compounding; the CL drops the
          # request otherwise. Point at the fix rather than letting it be dropped.
          if [[ "${target_creds:2:2}" == "00" ]]; then
            echo "Error: target validator $target_index still has BLS (0x00) withdrawal credentials, so it cannot receive a consolidation."
            echo "  Give it an execution address first, then self-consolidate it to 0x02:"
            echo "    ${0} set_withdrawal_addr $target_index $target_index <address>"
            echo "    ${0} consolidate $target_index"
            exit 1
          fi
          if [[ "${target_creds:2:2}" != "02" ]]; then
            echo "Error: target validator $target_index does not have compounding (0x02) withdrawal credentials, so it cannot receive a consolidation."
            echo "  Self-consolidate it first and wait for that request to be processed, then re-run this:"
            echo "    ${0} consolidate $target_index"
            exit 1
          fi
          if [[ "$target_status" != "active_ongoing" ]]; then
            echo "Error: target validator $target_index is $target_status; the target must be active and not exiting."
            exit 1
          fi
        fi

        # The predeploy keeps whatever value is sent and its fee climbs with every
        # request queued beyond MAX_CONSOLIDATION_REQUESTS_PER_PAYLOAD per block, so
        # a batch priced at the current fee can face a higher one by the time the
        # later transactions are mined. Overpay wildly — the fee is wei-scale, and
        # 1 gwei still covers a queue several hundred requests deep.
        fee_hex=$(cast call "$consolidation_contract" --rpc-url "$rpc_endpoint" 2>/dev/null)
        fee_wei=$(cast to-dec "$fee_hex" 2>/dev/null)
        if [[ ! "$fee_wei" =~ ^[0-9]+$ ]]; then
          echo "Could not read the current fee from the consolidation predeploy $consolidation_contract."
          exit 1
        fi
        send_fee=$((fee_wei * 8))
        (( send_fee < 1000000000 )) && send_fee=1000000000
        send_fee="${CONSOLIDATION_FEE_WEI:-$send_fee}"

        # The request must be signed by the source validators' withdrawal address.
        # Genesis validators point at the genesis generator's default address, whose
        # key is not derivable from the mnemonic — only validators deposited with an
        # address off this mnemonic can be consolidated, unless a key is passed in.
        privatekey="${CONSOLIDATION_PRIVATE_KEY:-}"
        if [[ -z "$privatekey" ]]; then
          for n in {0..15}; do
            hd_keys=$(ethereal hd keys --path="m/44'/60'/0'/0/$n" --seed="$sops_mnemonic")
            hd_address=$(echo "$hd_keys" | awk '/Ethereum address/{print $NF}')
            if [[ "${hd_address:l}" == "${sender_address:l}" ]]; then
              privatekey=$(echo "$hd_keys" | awk '/Private key/{print $NF}')
              signer_account="mnemonic account $n"
              break
            fi
          done
        else
          signer_account="CONSOLIDATION_PRIVATE_KEY"
        fi
        if [[ -z "$privatekey" ]]; then
          echo "No private key found for withdrawal address $sender_address (searched mnemonic accounts 0-15)."
          echo "  Consolidation requests must come from that address; pass its key with CONSOLIDATION_PRIVATE_KEY=0x..."
          exit 1
        fi

        echo ""
        if [[ "$consolidate_mode" == "self" ]]; then
          echo "Switch-to-compounding Summary:"
        else
          echo "Consolidation Summary:"
        fi
        echo "  Sources: ${#source_indices} validator(s)"
        if (( ${#source_indices} <= 20 )); then
          for ((i=1; i<=${#source_indices}; i++)); do
            echo "    ${source_indices[$i]}: ${source_pubkeys[$i]}"
          done
        else
          echo "    ${source_indices[1]} .. ${source_indices[-1]}"
        fi
        if [[ "$consolidate_mode" == "consolidate" ]]; then
          echo "  Target: $target_index ($target_pubkey)"
        else
          echo "  Target: each source itself (0x01 -> 0x02 credentials)"
        fi
        echo "  From: $sender_address ($signer_account)"
        echo "  Contract: $consolidation_contract"
        echo "  Fee: $fee_wei wei, sending $send_fee wei per request"
        echo ""
        echo "Continue? (y/n)"
        read -r response

        if [[ $response == "y" ]]; then
          tmpdir=$(mktemp -d)

          nonce_hex=$(curl -s --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'$sender_address'","pending"],"id":0}' $rpc_endpoint | jq -r '.result')
          nonce=$(( ${nonce_hex} ))
          echo "Starting nonce: $nonce"
          echo ""

          # zsh's background job table caps at 1024; batch so the active set stays well below.
          batch_size=500
          i=0
          for validator_index in "${source_indices[@]}"; do
            source_pubkey="${source_pubkeys[$((i + 1))]}"
            if [[ "$consolidate_mode" == "self" ]]; then
              request_target="$source_pubkey"
            else
              request_target="$target_pubkey"
            fi
            # Calldata is source_pubkey (48 bytes) ++ target_pubkey (48 bytes).
            echo "Sending consolidation request for validator $validator_index (nonce: $((nonce + i)))"
            echo "$validator_index" > "$tmpdir/cast-$i.name"
            cast send \
              --private-key "$privatekey" \
              --rpc-url "$rpc_endpoint" \
              --nonce $((nonce + i)) \
              --value "$send_fee" \
              --gas-limit 2000000 \
              "$consolidation_contract" \
              "0x${source_pubkey#0x}${request_target#0x}" > "$tmpdir/cast-$i.log" 2>&1 &
            i=$((i + 1))
            if (( i % batch_size == 0 )); then
              wait
              echo "Drained batch — $i submitted so far..."
            fi
          done

          echo "Submitted $i consolidation requests in batches of $batch_size, waiting for final batch..."
          wait
          echo ""
          ok=0
          fail=0
          for ((j=0; j<i; j++)); do
            log="$tmpdir/cast-$j.log"
            name=$(cat "$tmpdir/cast-$j.name" 2>/dev/null)
            txhash=$(grep -E '^transactionHash' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            tx_status=$(grep -E '^status' "$log" 2>/dev/null | awk '{print $2}' | head -1)
            if [[ "$tx_status" == "1" ]]; then
              printf "  \033[32m✓\033[0m validator %s — %s\n" "$name" "$txhash"
              ok=$((ok + 1))
            else
              printf "  \033[31m✗\033[0m validator %s — failed (status=%s tx=%s)\n" \
                "$name" "${tx_status:-no-receipt}" "${txhash:-none}"
              grep -iE 'error|revert' "$log" 2>/dev/null | head -1 | sed 's/^/      /'
              fail=$((fail + 1))
            fi
          done
          echo ""
          echo "$ok confirmed, $fail failed (of $i submitted)"
          echo "A confirmed request is only accepted by the CL if it still passes the checks at inclusion; watch the queue:"
          echo "  curl -s $bn_endpoint/eth/v1/beacon/states/head/pending_consolidations | jq"
          rm -rf "$tmpdir"
          exit;
        else
          echo "Consolidation cancelled."
          exit;
        fi
      fi
      ;;
    "exit")
      # if I have 1 argument, then use that as the validator index, else use second and third in a loop
      # if there are less than 2 arguments, then exit
      if [[ $# -lt 2 ]]; then
        echo "Exit calls for at least one arguments and at most two!"
        echo "  Usage: ${0} exit startIndex (endIndex)"
        echo "  Example: ${0} exit 10"
        echo "  Example: ${0} exit 0 10"
        exit;
      else
        if [[ -n "${command[3]}" ]]; then
          echo "Exiting validators from ${command[2]} to ${command[3]}"
          # Always regenerate offline-preparation.json for fresh chain state
          rm -f offline-preparation.json
          ethdo validator exit --prepare-offline --connection=$bn_endpoint --timeout=300s
          echo "[" > exit.json
          first_entry=true
          for i in $(seq ${command[2]} $((command[3] - 1)))
          do
            echo "Processing validator $i"
            # Try to generate exit operation, continue if validator is already exiting
            if ethdo validator exit --offline --mnemonic="$sops_mnemonic" --path="m/12381/3600/$i/0/0" 2>/dev/null; then
              echo "Exit operation generated for validator $i"
              # Add comma if not first entry
              if [[ "$first_entry" != "true" ]]; then
                echo "," >> exit.json
              fi
              # Append just the JSON content without array brackets
              cat exit-operations.json >> exit.json
              first_entry=false
            else
              echo "Skipping validator $i (may be already exiting or not active)"
            fi
          done
          echo "]" >> exit.json
          mv exit.json exit-operations.json
          ethdo validator exit --connection=$bn_endpoint --timeout=300s
          echo "validator exit submitted for validators ${command[2]} to $((command[3] - 1))"
          exit;
        else
          echo "Exiting validator ${command[2]}"
          ethdo validator exit --mnemonic="$sops_mnemonic" --connection=$bn_endpoint --offline --path="m/12381/3600/${command[2]}/0/0"
          echo "validator $i exit submitted"
          exit;
        fi
        exit;
      fi
      ;;
    "slash")
      # Trigger an assertoor proposer-slashing run against a single validator
      # or an inclusive contiguous range. The validator-slashing-single playbook
      # takes a start index and a count, so ranges must be contiguous (start..end).
      # The genesis mnemonic is passed through so the slashing targets this
      # devnet's validators rather than the playbook's hardcoded kurtosis default.
      if [[ -z "${command[2]}" ]]; then
        echo "Slash calls for one validator index or an inclusive range!"
        echo "  Usage: ${0} slash index"
        echo "         ${0} slash start..end"
        echo "  Example: ${0} slash 0       # slash validator 0"
        echo "  Example: ${0} slash 0..2    # slash validators 0, 1, 2"
        exit;
      else
        slash_arg="${command[2]}"
        if [[ "$slash_arg" =~ ^[0-9]+\.\.[0-9]+$ ]]; then
          slash_start=${slash_arg%%..*}
          slash_end=${slash_arg##*..}
          if (( slash_start > slash_end )); then
            echo "Error: invalid range '$slash_arg' (start > end)."
            exit 1
          fi
        elif [[ "$slash_arg" =~ ^[0-9]+$ ]]; then
          slash_start=$slash_arg
          slash_end=$slash_arg
        else
          echo "Error: '$slash_arg' is not a valid validator index or range."
          exit 1
        fi
        slash_count=$((slash_end - slash_start + 1))

        echo "Slashing validator(s) $slash_start..$slash_end ($slash_count total) on ${prefix}-${network}"
        echo "  Assertoor: $assertoor_endpoint"
        echo "Continue? (y/n)"
        read -r response
        if [[ $response != "y" ]]; then
          echo "Slashing cancelled."
          exit;
        fi

        slash_token=$(get_assertoor_token) || exit 1

        # Make sure the slashing test is registered; on a fresh assertoor it
        # won't be, so register it from the upstream playbook before scheduling.
        slash_registered=$(curl -s -H "Authorization: Bearer $slash_token" \
          "$assertoor_endpoint/api/v1/tests" \
          | jq -r --arg id "$slashing_test_id" '[.data[]?.id] | index($id) != null')
        if [[ "$slash_registered" != "true" ]]; then
          echo "Test '$slashing_test_id' not registered; registering from $slashing_playbook"
          slash_reg=$(curl -s \
            -H "Authorization: Bearer $slash_token" \
            -H "Content-Type: application/json" \
            -X POST "$assertoor_endpoint/api/v1/tests/register_external" \
            -d "$(jq -n --arg file "$slashing_playbook" '{file: $file}')")
          if [[ "$(echo "$slash_reg" | jq -r '.data.test_id // empty')" != "$slashing_test_id" ]]; then
            echo "Failed to register slashing test:"
            echo "$slash_reg" | jq . 2>/dev/null || echo "$slash_reg"
            exit 1
          fi
          echo "Registered test '$slashing_test_id'"
        fi

        slash_payload=$(jq -n \
          --arg test "$slashing_test_id" \
          --arg mnemonic "$sops_mnemonic" \
          --argjson index "$slash_start" \
          --argjson count "$slash_count" \
          '{test_id: $test, allow_duplicate: true,
            config: {validatorMnemonic: $mnemonic, validatorIndex: $index, validatorCount: $count}}')

        slash_response=$(curl -s \
          -H "Authorization: Bearer $slash_token" \
          -H "Content-Type: application/json" \
          -X POST "$assertoor_endpoint/api/v1/test_runs/schedule" \
          -d "$slash_payload")

        slash_status=$(echo "$slash_response" | jq -r '.status // empty' 2>/dev/null)
        if [[ "$slash_status" != "OK" ]]; then
          echo "Failed to schedule slashing run:"
          echo "$slash_response" | jq . 2>/dev/null || echo "$slash_response"
          # A rejected Bearer token means the cached JWT is stale/invalid;
          # drop it so the next run mints a fresh one.
          if [[ "$slash_status" == *unauthorized* ]]; then
            rm -f "${TMPDIR:-/tmp}/.assertoor_token_${prefix}-${network}.json"
            echo "(cleared cached auth token — re-run to mint a fresh one)" >&2
          fi
          exit 1
        fi
        slash_run_id=$(echo "$slash_response" | jq -r '.data.run_id')
        echo "Scheduled slashing run #$slash_run_id"
        echo "  Watch: $assertoor_endpoint/run/$slash_run_id"
        exit;
      fi
      ;;
    "set_withdrawal_addr")
      if [[ $# -ne 4 ]]; then
        echo "setting  calls for exactly 3 arguments!"
        echo "  Usage: ${0} set_withdrawal_addr startIndex endIndex address"
        echo "  Example: ${0} set_withdrawal_addr 0 10 0xf97e180c050e5Ab072211Ad2C213Eb5AEE4DF134"
        exit;
      else
        echo "Setting withdrawal credentials for validators ${command[2]} to ${command[3]} to address ${command[4]}"
        # generate the withdrawal credentials
        for i in $(seq ${command[2]} ${command[3]})
        do
          ethdo --connection=$bn_endpoint validator credentials set --mnemonic="$sops_mnemonic" --path="m/12381/3600/$i/0/0" --withdrawal-address="${command[4]}"
          echo "Withdrawal credentials set for validator $i"
        done
        exit;
      fi
      ;;
    "full_withdrawal")
      if [[ $# -ne 3 ]]; then
        echo "withdrawal calls for exactly 2 arguments!"
        echo "  Usage: ${0} full_withdrawal startIndex endIndex"
        echo "  Example: ${0} full_withdrawal 0 10"
        exit;
      else
        # create folder for withdrawal data
        mkdir -p /tmp/full_withdrawal

        ethdo wallet create --base-dir=/tmp/full_withdrawal --type=hd --wallet=withdrawal-validators --mnemonic=$sops_mnemonic --wallet-passphrase="superSecure" --allow-weak-passphrases
        echo "Local wallet has been created to process mnemonic and withdrawal data"

        # ask if you want to do a full withdrawal to the network
        echo "Are you sure you want to make a full withdrawal to the network for validators ${command[2]} to ${command[3]}? (y/n)"
        read -r response
        if [[ $response == "y" ]]; then
          # Loop through all the validator indexes that want to be withdrawn
          for i in $(seq ${command[2]} ${command[3]})
          do
              # Create an account from previous wallet, this will basically be the derivation path pub/private keypair
              ethdo account create --base-dir=/tmp/full_withdrawal --account=withdrawal-validators/$i --wallet-passphrase="superSecure" --passphrase="superSecure" --allow-weak-passphrases --path="m/12381/3600/$i/0/0"

              # Create JSON exit data and for earlier specified account and store it in disk
              ethdo validator exit --base-dir=/tmp/full_withdrawal --json --account=withdrawal-validators/$i --passphrase="superSecure" --connection=$bn_endpoint > /tmp/full_withdrawal/withdrawal-$i.json
              echo "generated exit data for validator number $i , now exiting..."
              ethdo validator exit --signed-operations=$(cat /tmp/full_withdrawal/withdrawal-$i.json) --connection=$bn_endpoint
          done
          # Cleanup wallet as its no longer needed
          ethdo wallet delete --base-dir=/tmp/full_withdrawal --wallet=withdrawal-validators
        else
          echo "Exiting without withdrawal to the network"
          exit;
        fi

        # deleting stale files
        rm -rf /tmp/set_withdrawal_addr
        echo
      fi
      ;;
    "check_deps")
      check_deps 1 || exit 1
      ;;
    "help")
      print_usage "${command[@]}"
      ;;

    *)
      echo "Invalid argument: $arg"
      print_usage "${command[@]}"
      ;;
  esac
done
