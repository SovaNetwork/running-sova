#!/bin/bash

# Resources:
# https://github.com/PowVT/satoshi-suite
# https://github.com/SovaNetwork/running-sova
# https://github.com/foundry-rs

# Requirements:
# - satoshi-suite
# - foundry (cast)
# - jq (for JSON parsing)
# - bc (for calculations)
# - curl

# This script tests double-spend functionality for a dev sova-reth node using bitcoin regtest
#
# It:
# 1. Creates a Bitcoin transaction, with 0.001 BTC fee
# 2. Submits the BTC transaction to  wrapped BTC contract for deposit.
# 3. User tries to transfer wrapped BTC erc20 tokens to another wallet. (This tests the slot lock enforcement on the slots where there was a SSTORE op code.)
# 4. Confirm the balance of the user and total supply slots in the sova contract after this contract call. (The balance should equal the amount of BTC deposited)
# 5. Mines confirmation blocks to ensure the BTC transaction is confirmed.
# 6. User tries to transfer wrapped BTC erc20 tokens to another wallet again. (This time the slots are unlocked by the sentinel and the transfer should succeed.)
# 7. Check the balance of the user and total supply slots again. (The balance should equal the amount of BTC deposited - amount of BTC transferred)

# Exit on error
set -e

# Configuration
WALLET_1="user"
WALLET_2="miner"
SOVABTC_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000020"  # native wrapped BTC predeploy address
SOVAL1BLOCK_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000015" # SovaL1Block predeploy address
SOVABTC_BITCOIN_RECEIVE_ADDRESS="bcrt1qrd4khgwjv27mmxndwzdslj3rjgk2l2uhk43u9k"  # deterministic address based on the network signing wallet's bip32 derivation path
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

# Function to check contract state with pending transactions
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

echo "Mining initial blocks..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_1" --blocks 1
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 100
update_sova_l1_block

echo "Creating Bitcoin transactions..."
# Transaction with 0.001 fee
TX1_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" sign-tx --wallet-name "$WALLET_1" --recipient "$SOVABTC_BITCOIN_RECEIVE_ADDRESS" --amount 49.999 --fee-amount 0.001)
TX1_HEX=$(get_tx_hex "$TX1_OUTPUT")

# For debugging
echo "TX1 Hex: $TX1_HEX"

# Convert 49.999 BTC to satoshis
AMOUNT_SATS=$(btc_to_sats 49.999)

# Find the vout index for the SovaBTC receive address
VOUT_INDEX=$(find_vout_index "$TX1_HEX" "$SOVABTC_BITCOIN_RECEIVE_ADDRESS")

if [ -z "$VOUT_INDEX" ]; then
    echo "Error: Could not find vout index for address $SOVABTC_BITCOIN_RECEIVE_ADDRESS"
    exit 1
fi

echo "Vout Index: $VOUT_INDEX"

echo "Submitting first deposit to wrapped BTC contract (0.001 fee)..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 250000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "depositBTC(uint64,bytes,uint8)" \
    "$AMOUNT_SATS" \
    "0x$TX1_HEX" \
    "$VOUT_INDEX"

check_contract_state "After deposit submission (before finalization)"

echo "Submitting erc20 transfer() call (should fail due to pending deposit)..."

# This should fail, cannot transfer before the BTC transaction is confirmed
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "transfer(address,uint256)" \
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
    "100"

check_contract_state "After failed transfer attempt (pending deposit)"

echo "Mining blocks to confirm btc tx..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 7
update_sova_l1_block

echo "Finalizing deposit..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After deposit finalization"

echo "Submitting erc20 transfer() call (should succeed now)..."

cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "transfer(address,uint256)" \
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
    "100"

check_contract_state "After successful transfer"

echo "Done!"