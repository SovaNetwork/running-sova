#!/bin/bash

# Resources:
# https://github.com/PowVT/satoshi-suite
# https://github.com/SovaNetwork/running-sova
# https://github.com/foundry-rs

# This script tests double-spend protection on a sova-reth execution client with SovaBTC
#
# It:
# 1. Creates two Bitcoin transactions spending the same UTXO:
#    - First with 0.001 BTC fee
#    - Second with 0.01 BTC fee (broadcasted to Bitcoin network)
# 2. Submits the first transaction to SovaBTC contract for deposit
# 3. Broadcasts the second transaction to Bitcoin network in same bitcoin block
# 4. Mines confirmation blocks to ensure the double spend Bitcoin transaction is confirmed
# 5. Check the balanceOf user, pending deposits, and total supply slots in the sova SovaBTC smart contract
# 6. User creates another Bitcoin transaction for a deposit of the same amount and sends to the node
# 7. Finalizes pending transactions and checks the contract state
# 8. Confirm bitcoin transaction by mining bitcoin blocks
# 9. Tests withdrawal functionality after the double-spend attack

# Exit on error
set -e

# Configuration
WALLET_1="user"
WALLET_2="miner"
SOVABTC_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000020" # native wrapped BTC predeploy address
SOVABTC_BITCOIN_RECEIVE_ADDRESS="bcrt1qrd4khgwjv27mmxndwzdslj3rjgk2l2uhk43u9k"  # deterministic address based on the network signing wallet's bip32 derivation path
DOUBLE_SPEND_RECEIVE_ADDRESS="bcrt1q6xxa0arlrk6jdz02alxc6smdv5g953v7zkswaw" # random address for double spend
ETH_RPC_URL="http://localhost:8545"
ETH_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ETH_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN_ID="120893"

# Bitcoin RPC Configuration
BTC_RPC_URL="http://localhost"
BTC_RPC_USER="user"
BTC_RPC_PASS="password"
BTC_NETWORK="regtest"

# UTXO Indexer Configuration
INDEXER_DB_HOST="localhost"
INDEXER_DB_PORT="5557"
INDEXER_DB_URL="http://${INDEXER_DB_HOST}:${INDEXER_DB_PORT}"

# Function to convert BTC to smallest unit (satoshis)
btc_to_sats() {
    echo "$1 * 100000000" | bc | cut -d'.' -f1
}

# Function to find vout index for users SovaBTC deposit address
# Debug version to see what's happening
find_vout_index_debug() {
    local tx_hex=$1
    local target_address=$2

    echo "=== DEBUG find_vout_index ===" >&2
    echo "Target address: $target_address" >&2

    # Decode transaction and parse the output
    local decode_output=$(satoshi-suite decode-raw-tx --tx-hex "$tx_hex" 2>/dev/null)

    # Convert target address to uppercase for comparison
    local target_upper=$(echo "$target_address" | tr '[:lower:]' '[:upper:]')
    echo "Target uppercase: $target_upper" >&2

    # Check if address exists in output
    echo "Address found in output:" >&2
    echo "$decode_output" | grep "$target_upper" >&2

    # Find line number
    local address_line_num=$(echo "$decode_output" | grep -n "$target_upper" | head -1 | cut -d: -f1)
    echo "Address line number: $address_line_num" >&2
    
    if [ -n "$address_line_num" ]; then
        echo "Lines up to address:" >&2
        echo "$decode_output" | head -n "$address_line_num" | grep "n: [0-9]" >&2
        
        # Get the result
        local result=$(echo "$decode_output" | head -n "$address_line_num" | grep "n: [0-9]" | tail -1 | sed 's/.*n: \([0-9]\+\).*/\1/')
        echo "Final result: $result" >&2
        echo "$result"
    else
        echo "Address not found!" >&2
    fi
    echo "=== END DEBUG ===" >&2
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

echo "Creating Bitcoin transactions..."
# First transaction with 0.001 fee
TX1_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" sign-tx --wallet-name "$WALLET_1" --recipient "$SOVABTC_BITCOIN_RECEIVE_ADDRESS" --amount 49.999 --fee-amount 0.001)
TX1_HEX=$(get_tx_hex "$TX1_OUTPUT")

# Second transaction with 0.01 fee (double spend)
TX2_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" sign-tx --wallet-name "$WALLET_1" --recipient "$DOUBLE_SPEND_RECEIVE_ADDRESS" --amount 49.99 --fee-amount 0.01)
TX2_HEX=$(get_tx_hex "$TX2_OUTPUT")

# For debugging
echo "TX1 Hex: $TX1_HEX"
echo "TX2 Hex: $TX2_HEX"

# optional/debugging: decode the raw transaction
echo "Decoding raw transaction..."
satoshi-suite decode-tx --tx-hex "$TX1_HEX"


# Convert 49.999 BTC to satoshis
AMOUNT_SATS=$(btc_to_sats 49.999)

# Find the vout index for the SovaBTC receive address
VOUT_INDEX=$(find_vout_index "$TX1_HEX" "$SOVABTC_BITCOIN_RECEIVE_ADDRESS")

if [ -z "$VOUT_INDEX" ]; then
    echo "Error: Could not find vout index for address $SOVABTC_BITCOIN_RECEIVE_ADDRESS"
    exit 1
fi

echo "Vout Index: $VOUT_INDEX"

echo "Submitting first transaction to SovaBTC contract (0.001 fee)..."
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

check_contract_state "After first deposit submission (before finalization)"

echo "Broadcasting competing Bitcoin transaction (0.01 fee)..."
TX_BROADCAST_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" broadcast-tx --tx-hex "$TX2_HEX")
TX_ID=$(echo "$TX_BROADCAST_OUTPUT" | grep "Broadcasted transaction:" | cut -d' ' -f3)

echo "Mining confirmation blocks for double-spend transaction..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 19
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_1" --blocks 1
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 100

echo "Attempting to finalize first deposit (should succeed and revert the pending balance slot back to zero due to double spend)..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After attempting to finalize double-spend deposit"

echo "Creating new Bitcoin transaction for second VALID deposit..."
TX3_OUTPUT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" sign-tx --wallet-name "$WALLET_1" --recipient "$SOVABTC_BITCOIN_RECEIVE_ADDRESS" --amount 49.999 --fee-amount 0.001)
TX3_HEX=$(get_tx_hex "$TX3_OUTPUT")

# Find the vout index for the SovaBTC receive address
VOUT_INDEX=$(find_vout_index "$TX3_HEX" "$SOVABTC_BITCOIN_RECEIVE_ADDRESS")

if [ -z "$VOUT_INDEX" ]; then
    echo "Error: Could not find vout index for address $SOVABTC_BITCOIN_RECEIVE_ADDRESS"
    exit 1
fi

echo "Vout Index: $VOUT_INDEX"

echo "Submitting second deposit to SovaBTC contract..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 250000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "depositBTC(uint64,bytes,uint8)" \
    "$AMOUNT_SATS" \
    "0x$TX3_HEX" \
    "$VOUT_INDEX"

check_contract_state "After second deposit submission (before finalization)"

echo "Mining confirmation blocks for second deposit..."
satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" mine-blocks --wallet-name "$WALLET_2" --blocks 7

echo "Finalizing second deposit..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After finalizing second deposit"

# Get current Bitcoin block height
BTC_BLOCK_HEIGHT=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" get-block-height | grep "Current block height:" | cut -d' ' -f8)

# set withdrawal amount to 10.00 BTC and a 0.01 BTC fee
WITHDRAWAL_AMOUNT=$(btc_to_sats 10.00)
WITHDRAWAL_FEE=$(btc_to_sats 0.01)

echo "Waiting for UTXO indexer to catch up..."
while true; do
    RESPONSE=$(curl -s "${INDEXER_DB_URL}/latest-block")
    LATEST_BLOCK=$(echo $RESPONSE | jq -r '.latest_block')
    echo "Current BTC block height: $BTC_BLOCK_HEIGHT"
    echo "Latest indexed block: $LATEST_BLOCK"
    
    if [ "$LATEST_BLOCK" -ge "$BTC_BLOCK_HEIGHT" ]; then
        UTXOS=$(curl -s "${INDEXER_DB_URL}/spendable-utxos/block/$BTC_BLOCK_HEIGHT/address/$SOVABTC_BITCOIN_RECEIVE_ADDRESS")
        
        # Check if we got an error response
        if ! echo "$UTXOS" | jq -e '.error' > /dev/null; then
            TOTAL_AMOUNT=$(echo "$UTXOS" | jq -r '.total_amount')
            echo "Found UTXOs worth $TOTAL_AMOUNT satoshis"
            if [ "$TOTAL_AMOUNT" -gt "$WITHDRAWAL_AMOUNT" ]; then
                echo "Sufficient UTXOs found for withdrawal of $WITHDRAWAL_AMOUNT satoshis"
                break
            fi
        else
            echo "Waiting for UTXOs to be indexed..."
        fi
    fi
    sleep 2
done

echo "Initiating withdrawal..."

# Generate new Bitcoin address for withdrawal
NEW_ADDRESS=$(satoshi-suite --rpc-url "$BTC_RPC_URL" --network "$BTC_NETWORK" --rpc-username "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASS" get-new-address --wallet-name "$WALLET_1" | grep "New address:" | cut -d' ' -f7)

cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 300000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "withdraw(uint64,uint64,uint64,string)" \
    "$WITHDRAWAL_AMOUNT" \
    "$WITHDRAWAL_FEE" \
    "$BTC_BLOCK_HEIGHT" \
    "$NEW_ADDRESS"

check_contract_state "After withdrawal submission (before finalization)"

echo "Finalizing withdrawal..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$SOVABTC_CONTRACT_ADDRESS" \
    "finalize(address)" \
    "$ETH_ADDRESS"

check_contract_state "After withdrawal finalization"

# echo "Testing transfer (should work when no pending transactions)..."
# cast send \
#     --rpc-url "$ETH_RPC_URL" \
#     --private-key "$ETH_PRIVATE_KEY" \
#     --gas-limit 100000 \
#     --chain-id "$CHAIN_ID" \
#     "$SOVABTC_CONTRACT_ADDRESS" \
#     "transfer(address,uint256)" \
#     "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
#     "100"

# check_contract_state "After transfer"

echo "Done!"