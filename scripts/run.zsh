#!/bin/zsh
node="bootnode-1"
network="devnet-0"
prefix="testing"
sops_name=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_nginx_shared_basic_auth.name')
sops_password=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_nginx_shared_basic_auth.password')
sops_mnemonic=$(sops --decrypt ../ansible/inventories/$network/group_vars/all/all.sops.yaml | yq -r '.secret_genesis_mnemonic')
network_subdomain=$(yq -r '.network_subdomain' ../ansible/inventories/$network/group_vars/all/all.yaml)
network_server_subdomain=$(yq -r '.network_server_subdomain' ../ansible/inventories/$network/group_vars/all/all.yaml)
rpc_prefix=$(yq -r '.ethereum_node_rpc_prefix' ../ansible/inventories/$network/group_vars/all/all.yaml)
beacon_prefix=$(yq -r '.ethereum_node_rpc_prefix' ../ansible/inventories/$network/group_vars/all/all.yaml)
bn_endpoint="${BEACON_ENDPOINT:-https://$sops_name:$sops_password@$beacon_prefix$node.$network_server_subdomain}"
rpc_endpoint="${RPC_ENDPOINT:-https://$sops_name:$sops_password@$rpc_prefix$node.$network_server_subdomain}"
bootnode_endpoint="${BOOTNODE_ENDPOINT:-https://bootnode-1.$network_server_subdomain}"

# Helper function to display available options
print_usage() {
  echo "Usage:"
  echo "  ./run.zsh [command]"
  echo
  echo "Available commands:"
  echo "  genesis                           Get the genesis block"
  echo "  validators                        Get the validator ranges"
  echo "  latest_root                       Get the latest root"
  echo "  latest_slot                       Get the latest slot"
  echo "  latest_slot_verbose               Get the latest slot with verbose output"
  echo "  latest_block                      Get the latest block"
  echo "  get_slot n                        Get the slot number n [default head]"
  echo "  get_block n                       Get the block number n [default latest]"
  echo "  get_balance address               Get the balance of address - mandatory argument"
  echo "  finalized_epoch                   Get the finalized epoch"
  echo "  finalized_slot                    Get the finalized slot"
  echo "  finalized_slot_verbose            Get the finalized slot with verbose output"
  echo "  finalized_slot_exec_payload       Get the finalized slot execution payload"
  echo "  epoch_summary n                   Get the epoch summary for epoch n [default current - 1 epoch]"
  echo "  get_slot_for_blob txhash          Get the slot for a given blob given txhash, or send blob now"
  echo "  get_slot_for_blob_verbose txhash  Get the slot for a given blob with verbose output given txhash, or send blob now"
  echo "  get_block_for_slot n              Get the block for a given slot - mandatory argument"
  echo "  whose_validator_for_slot n        Get the validator for a given slot "n" - mandatory argument"
  echo "  get_enrs                          Get the ENRs of the network"
  echo "  get_enodes                        Get the enodes of the network"
  echo "  get_peerid                        Get the peerid of the network"
  echo "  get_rpc                           Get the rpc of the network"
  echo "  get_beacon                        Get the beacon of the network"
  echo "  get_inventory                     Get the inventory of the network"
  echo "  fork_choice                       Get the fork choice of the network"
  echo "  send_blob n                       Send "n" number of blob(s) to the network [default 1]"
  echo "  deposit s e [type]                Deposit to the network from validator index start to end - optional withdrawal type (0x00, 0x01, 0x02)"
  echo "  topup validator_index[,index2,...] eth_amount  Top-up one or more validators with additional ETH (Pectra upgrade feature)"
  echo "  exit s e                          Exit from the network from validator index start to end - mandatory argument"
  echo "  set_withdrawal_addr s e address   Set the withdrawal credentials for validator index start (mandatory) to end (optional) and Ethereum address"
  echo "  full_withdrawal s e               Withdraw from the network from validator index start to end - mandatory argument"
  echo "  help                              Print this help message"
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
        balance=$(curl -s  --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"eth_getBalance", "params":["'${command[2]}'","latest"], "id":0}' $rpc_endpoint | jq -r '.result' | python -c "import sys; print(int(sys.stdin.read(), 16) / 1e18)")
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
          while read x; do
            account_name="$(echo "$x" | jq '.account')"
            pubkey="$(echo "$x" | jq '.pubkey')"
            echo "Sending deposit for validator $account_name $pubkey"
            ethereal beacon deposit \
              --allow-unknown-contract=true \
              --address="$deposit_contract_address" \
              --connection=$rpc_endpoint \
              --data="$x" \
              --value="$deposit_amount" \
              --from="$publickey" \
              --privatekey="$privatekey" \
              --allow-excessive-deposit
            echo "Sent deposit for validator $account_name $pubkey"
            sleep 5
          done < deposits_$prefix-$network-${command[2]}_${command[3]}.txt
          exit;
        else
          echo "Exiting without depositing to the network"
          exit;
        fi
      fi
      ;;
    "topup")
      # Top-up one or more validators with additional ETH (Pectra upgrade feature)
      if [[ $# -ne 3 ]]; then
        echo "Top-up calls for exactly 2 arguments!"
        echo "  Usage: ${0} topup validator_index[,index2,...] eth_amount"
        echo "  Example: ${0} topup 5 35"
        echo "  Example: ${0} topup 1,2,3 10"
        exit;
      else
        validator_indices=${command[2]}
        eth_amount=${command[3]}

        # Validate ETH amount
        if ! [[ "$eth_amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$eth_amount < 1" | bc -l) )); then
          echo "Error: ETH amount must be >= 1."
          exit 1
        fi

        # Parse validator indices (handle both single index and comma-separated list)
        VALIDATOR_ARRAY=(${(s:,:)validator_indices})

        # Validate all validator indices and get their info
        declare -a validator_pubkeys

        for validator_index in "${VALIDATOR_ARRAY[@]}"; do
          # Validate that each index is a number
          if ! [[ "$validator_index" =~ ^[0-9]+$ ]]; then
            echo "Error: Validator index '$validator_index' must be a positive integer."
            exit 1
          fi

          # Get validator info
          validator_info=$(curl -s "$bn_endpoint/eth/v1/beacon/states/head/validators/$validator_index")
          if [[ $(echo "$validator_info" | jq -r '.data') == "null" ]]; then
            echo "Error: Validator $validator_index not found."
            exit 1
          fi

          validator_pubkey=$(echo "$validator_info" | jq -r '.data.validator.pubkey')
          validator_pubkeys+=("$validator_pubkey")
        done

        # Get common info
        deposit_contract_address=$(curl -s $bn_endpoint/eth/v1/config/spec | jq -r '.data.DEPOSIT_CONTRACT_ADDRESS')
        deposit_path="m/44'/60'/0'/0/7"
        privatekey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Private key/{print $NF}')
        publickey=$(ethereal hd keys --path="$deposit_path" --seed="$sops_mnemonic" | awk '/Ethereum address/{print $NF}')

        echo ""
        echo "Top-up Summary:"
        echo "  Validators: ${#VALIDATOR_ARRAY} validator(s)"
        for ((i=1; i<=${#VALIDATOR_ARRAY}; i++)); do
          echo "    ${VALIDATOR_ARRAY[$i]}: ${validator_pubkeys[$i]}"
        done
        echo "  Amount per validator: $eth_amount ETH"
        echo "  Total amount: $(echo "${#VALIDATOR_ARRAY} * $eth_amount" | bc) ETH"
        echo "  Deposit Contract: $deposit_contract_address"
        echo ""
        echo "Continue? (y/n)"
        read -r response

        if [[ $response == "y" ]]; then
          echo "Submitting top-ups using ethereal..."
          echo ""

          # Process each validator
          for ((i=1; i<=${#VALIDATOR_ARRAY}; i++)); do
            validator_index="${VALIDATOR_ARRAY[$i]}"
            validator_pubkey="${validator_pubkeys[$i]}"

            echo "Processing validator $validator_index ($i/${#VALIDATOR_ARRAY})..."
            echo "Command: ethereal validator topup --from=\"$publickey\" --validator=\"$validator_pubkey\" --topup-amount=\"${eth_amount}eth\" --no-safety-checks"

            # Submit topup for this validator with retry logic
            topup_success=false
            for retry in {1..3}; do
              echo "Attempt $retry/3..."
              topup_output=$(ethereal validator topup \
                --from="$publickey" \
                --validator="$validator_pubkey" \
                --topup-amount="${eth_amount}eth" \
                --privatekey="$privatekey" \
                --connection="$rpc_endpoint" \
                --consensus-connection="$bn_endpoint" \
                --no-safety-checks \
                --timeout=60s 2>&1)

              if [[ $? -eq 0 ]]; then
                topup_success=true
                break
              else
                echo "Attempt $retry failed. Error: $topup_output"
                if [[ $retry -lt 3 ]]; then
                  echo "Retrying in 5 seconds..."
                  sleep 5
                fi
              fi
            done

            if [[ "$topup_success" == "true" ]]; then
              # Extract transaction hash from output
              tx_hash=$(echo "$topup_output" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)
              if [[ -n "$tx_hash" ]]; then
                echo "Transaction hash: $tx_hash"
                echo "Waiting for transaction confirmation..."

                # Wait for transaction to be mined
                for attempt in {1..30}; do
                  receipt_response=$(curl -s --header 'Content-Type: application/json' --data-raw "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\", \"params\":[\"$tx_hash\"], \"id\":0}" $rpc_endpoint)

                  # Debug: show raw response if it's not valid JSON
                  if ! echo "$receipt_response" | jq . >/dev/null 2>&1; then
                    echo "Invalid JSON response: $receipt_response"
                    echo "Retrying..."
                    sleep 2
                    continue
                  fi

                  receipt_result=$(echo "$receipt_response" | jq -r '.result // empty')
                  if [[ -n "$receipt_result" && "$receipt_result" != "null" ]]; then
                    tx_status=$(echo "$receipt_result" | jq -r '.status // empty')
                    if [[ "$tx_status" == "0x1" ]]; then
                      echo "✓ Validator $validator_index top-up successful! (confirmed)"
                      break
                    else
                      echo "✗ Validator $validator_index top-up failed! (transaction reverted)"
                      break
                    fi
                  fi
                  echo "Waiting for confirmation... (attempt $attempt/30)"
                  sleep 2
                done

                if [[ $attempt -eq 30 ]]; then
                  echo "⚠ Transaction confirmation timeout for validator $validator_index"
                fi
              else
                echo "✓ Validator $validator_index top-up successful! (no tx hash found)"
              fi
            else
              echo "✗ Validator $validator_index top-up failed!"
              echo "Error output: $topup_output"
            fi
            echo ""

            # Small delay between transactions
            if [[ $i -lt ${#VALIDATOR_ARRAY} ]]; then
              echo "Waiting 2 seconds before next transaction..."
              sleep 2
            fi
          done

          echo "Top-up process completed for ${#VALIDATOR_ARRAY} validator(s)."
        else
          echo "Top-up cancelled."
        fi

        exit;
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
    "help")
      print_usage "${command[@]}"
      ;;

    *)
      echo "Invalid argument: $arg"
      print_usage "${command[@]}"
      ;;
  esac
done
