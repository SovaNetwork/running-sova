#!/bin/bash

# Simple SovaBTC deposit test
# This script only tests the depositBTC flow

# Requirements:
# - satoshi-suite
# - foundry (cast)
# - jq (for JSON parsing)
# - bc (for calculations)
# - curl

# Exit on error
set -e

# Configuration
WALLET_1="user"
WALLET_2="miner"
SOVABTC_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000020"
SOVAL1BLOCK_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000015" # SovaL1Block predeploy address
SOVABTC_BITCOIN_RECEIVE_ADDRESS="bcrt1qrd4khgwjv27mmxndwzdslj3rjgk2l2uhk43u9k"
ETH_RPC_URL="http://localhost:8545"
ETH_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ETH_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN_ID="120893"

# Bitcoin RPC Configuration
BTC_RPC_URL="http://localhost"
BTC_RPC_PORT="18443"  # Default regtest RPC port
BTC_RPC_USER="user"
BTC_RPC_PASS="password"
BTC_NETWORK="regtest"

# Tx configuration
TX_FEE=0.001 # in BTC
TX_AMOUNT=1.999 # in BTC

# Function to convert BTC to smallest unit (satoshis)
btc_to_sats() {
    echo "$1 * 100000000" | bc | cut -d'.' -f1
}

# Function to get Bitcoin block hash using Bitcoin Core RPC
get_block_hash() {
    local block_height=$1
    
    # Use Bitcoin Core RPC to get block hash by height
    local response=$(curl -s --user "$BTC_RPC_USER:$BTC_RPC_PASS" \
        --data-binary "{\"jsonrpc\": \"1.0\", \"id\":\"script\", \"method\": \"getblockhash\", \"params\": [$block_height]}" \
        -H 'content-type: text/plain;' \
        "${BTC_RPC_URL}:${BTC_RPC_PORT}/")
    
    # Check if response contains an error
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "Error getting block hash for height $block_height" >&2
        return 1
    fi
    
    # Extract hash from JSON response (remove quotes)
    local hash=$(echo "$response" | jq -r '.result')
    
    # Validate hash format (should be 64 hex characters)
    if [[ ! "$hash" =~ ^[a-fA-F0-9]{64}$ ]]; then
        echo "Invalid block hash format: $hash" >&2
        return 1
    fi
    
    echo "$hash"
}

# Function to update SovaL1Block with current Bitcoin state
update_sova_l1_block() {
    echo "Updating SovaL1Block contract with Bitcoin block data..."
    
    # Get current Bitcoin block height
    local current_height=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" get-block-height | grep "Current block height:" | cut -d' ' -f8)
    
    # Calculate height 6 blocks back (ensure it's not negative)
    local six_blocks_back=$((current_height - 6))
    if [ $six_blocks_back -lt 0 ]; then
        six_blocks_back=0
    fi
    
    # Get block hash from 6 blocks back
    local block_hash=$(get_block_hash $six_blocks_back)
    
    if [ $? -ne 0 ] || [ -z "$block_hash" ]; then
        echo "Warning: Could not get block hash for height $six_blocks_back, skipping SovaL1Block update"
        return
    fi
    
    echo "Current Bitcoin height: $current_height"
    echo "Setting L1Block with height: $current_height, hash from block $six_blocks_back: $block_hash"
    
    # Call setBitcoinBlockData on SovaL1Block contract
    cast send \
        --rpc-url "$ETH_RPC_URL" \
        --private-key "$ETH_PRIVATE_KEY" \
        --gas-limit 100000 \
        --chain-id "$CHAIN_ID" \
        "$SOVAL1BLOCK_CONTRACT_ADDRESS" \
        "setBitcoinBlockData(uint64,bytes32)" \
        "$current_height" \
        "0x$block_hash"
}

# Function to find vout index for users SovaBTC deposit address
find_vout_index() {
    local tx_hex=$1
    local target_address=$2

    # Decode transaction and parse the output
    local decode_output=$(satoshi-suite decode-raw-tx --tx-hex "$tx_hex" 2>/dev/null)

    # Convert target address to uppercase for comparison
    local target_upper=$(echo "$target_address" | tr '[:lower:]' '[:upper:]')

    # Extract vout entries and find the matching address
    echo "$decode_output" | awk -v target="$target_upper" '
        # Track current vout index
        /n: [0-9]+/ {
            n_value = $2
            gsub(/,/, "", n_value)
        }

        # Check for address match (case insensitive)
        /Address<NetworkUnchecked>\(/ {
            address_line = $0
            gsub(/.*Address<NetworkUnchecked>\(/, "", address_line)
            gsub(/\).*/, "", address_line)

            if (toupper(address_line) == target) {
                print n_value
                exit
            }
        }
    '
}

# Function to extract transaction hex
get_tx_hex() {
    local output=$1
    local hex=$(echo "$output" | grep "Signed transaction:" | sed 's/.*Signed transaction: //')
    echo "$hex"
}

# Function to check contract state
check_contract_state() {
    local description=$1
    echo "=== $description ==="
    
    BALANCE=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" \
        "balanceOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)
    TOTAL_SUPPLY=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" \
        "totalSupply()" | cast to-dec)
    PENDING_DEPOSIT=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" \
        "pendingDepositAmountOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)
    PENDING_WITHDRAWAL=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" \
        "pendingWithdrawalAmountOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)

    echo "Balance: $BALANCE satoshis"
    echo "Total Supply: $TOTAL_SUPPLY satoshis"
    echo "Pending Deposit: $PENDING_DEPOSIT satoshis"
    echo "Pending Withdrawal: $PENDING_WITHDRAWAL satoshis"
    echo ""
}

cd ~

echo "Creating Bitcoin wallets..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" new-wallet --wallet-name "$WALLET_1"
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" new-wallet --wallet-name "$WALLET_2"

echo "Mining initial blocks to fund wallet..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_1" --blocks 1
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 100
update_sova_l1_block

echo "Checking initial contract state..."
check_contract_state "Initial State"

echo "Creating Bitcoin transaction for deposit..."
TX_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" sign-tx --wallet-name "$WALLET_1" --recipient "$SOVABTC_BITCOIN_RECEIVE_ADDRESS" --amount "$TX_AMOUNT" --fee-amount "$TX_FEE")
TX_HEX=$(get_tx_hex "$TX_OUTPUT")

echo "Transaction Hex: $TX_HEX"

# optional/debugging: decode the raw transaction
# echo "Decoding raw transaction..."
# satoshi-suite decode-raw-tx --tx-hex "$TX_HEX"

# Convert TX_AMOUNT to satoshis 
AMOUNT_SATS=$(btc_to_sats $TX_AMOUNT)
echo "Deposit Amount: $AMOUNT_SATS satoshis"

# Find the vout index for the SovaBTC receive address
VOUT_INDEX=$(find_vout_index "$TX_HEX" "$SOVABTC_BITCOIN_RECEIVE_ADDRESS")

if [ -z "$VOUT_INDEX" ]; then
    echo "Error: Could not find vout index for address $SOVABTC_BITCOIN_RECEIVE_ADDRESS"
    exit 1
fi

echo "Vout Index: $VOUT_INDEX"

echo "Submitting deposit to SovaBTC contract..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 250000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "depositBTC(uint64,bytes,uint8)" \
    "$AMOUNT_SATS" \
    "0x$TX_HEX" \
    "$VOUT_INDEX"

check_contract_state "After Deposit Submission"

echo "Mining only 3 Bitcoin blocks (insufficient confirmations)..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 3
update_sova_l1_block

echo "Attempting to finalize with insufficient confirmations (should fail)..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After failed finalization attempt (3 blocks)"

echo "Mining 3 more Bitcoin blocks (total 6 confirmations)..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 3
update_sova_l1_block

echo "Finalizing deposit with sufficient confirmations..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After second successful finalization (6 blocks)"

echo "Checking contract configuration..."
MIN_DEPOSIT=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" "minDepositAmount()" | cast to-dec)
MAX_DEPOSIT=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" "maxDepositAmount()" | cast to-dec)
MAX_GAS=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" "maxGasLimitAmount()" | cast to-dec)
IS_PAUSED=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" "isPaused()")
OWNER=$(cast call --rpc-url "$ETH_RPC_URL" "$SOVABTC_CONTRACT_ADDRESS" "owner()")

echo "=== Contract Configuration ==="
echo "Min Deposit Amount: $MIN_DEPOSIT satoshis"
echo "Max Deposit Amount: $MAX_DEPOSIT satoshis"
echo "Max BTC Gas Limit: $MAX_GAS satoshis"
echo "Is Paused: $IS_PAUSED"
echo "Owner: $OWNER"
echo ""

echo "Simple deposit test completed successfully!"