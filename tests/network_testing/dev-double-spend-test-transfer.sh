#!/bin/bash

# Resources:
# https://github.com/PowVT/satoshi-suite
# https://github.com/SovaNetwork/running-sova
# https://github.com/foundry-rs

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
UBTC_CONTRACT_ADDRESS="0x2100000000000000000000000000000000000020"  # native wrapped BTC predeploy address
UBTC_BITCOIN_RECEIVE_ADDRESS="bcrt1qcur7cgvcmcpdqe5v6hpuppswgqqz7nrdgtxulx"  # deterministic address based on the network signing wallet's bip32 derivation path
ETH_RPC_URL="http://localhost:8545"
ETH_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ETH_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHAIN_ID="120893"

# Function to convert BTC to smallest unit (satoshis)
btc_to_sats() {
    echo "$1 * 100000000" | bc | cut -d'.' -f1
}

# Function to extract transaction hex
get_tx_hex() {
    local output=$1
    local hex=$(echo "$output" | grep "Signed transaction:" | sed 's/.*Signed transaction: //')
    echo "$hex"
}

cd ~

echo "Creating Bitcoin wallets..."
satoshi-suite new-wallet --wallet-name "$WALLET_1"
satoshi-suite new-wallet --wallet-name "$WALLET_2"

echo "Mining initial blocks..."
satoshi-suite mine-blocks --wallet-name "$WALLET_1" --blocks 1
satoshi-suite mine-blocks --wallet-name "$WALLET_2" --blocks 100

echo "Creating Bitcoin transactions..."
# Transaction with 0.001 fee
TX1_OUTPUT=$(satoshi-suite sign-tx --wallet-name "$WALLET_1" --recipient "$UBTC_BITCOIN_RECEIVE_ADDRESS" --amount 49.999 --fee-amount 0.001)
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

echo "Submitting first deposit to  wrapped BTC contract (0.001 fee)..."
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 250000 \
    --chain-id "$CHAIN_ID" \
    "$UBTC_CONTRACT_ADDRESS" \
    "depositBTC(uint64,bytes,uint8)" \
    "$AMOUNT_SATS" \
    "0x$TX1_HEX" \
    "$VOUT_INDEX"

echo "Checking contract state..."
    BALANCE=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "balanceOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)
    TOTAL_SUPPLY=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "totalSupply()" | cast to-dec)

    echo "Balance: $BALANCE"
    echo "Total Supply: $TOTAL_SUPPLY"

echo "Submitting erc20 transfer() call (should fail)..."

# This should fail, cannot transfer before the BTC transaction is confirmed
cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$UBTC_CONTRACT_ADDRESS" \
    "transfer(address,uint256)" \
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
    "100"

echo "Checking contract state..."
    BALANCE=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "balanceOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)
    TOTAL_SUPPLY=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "totalSupply()" | cast to-dec)

    echo "Balance: $BALANCE"
    echo "Total Supply: $TOTAL_SUPPLY"

echo "mining blocks to conifirm btc tx..."
satoshi-suite mine-blocks --wallet-name "$WALLET_2" --blocks 7

echo "Submitting erc20 transfer() call (should succeed)..."

cast send \
    --rpc-url "$ETH_RPC_URL" \
    --private-key "$ETH_PRIVATE_KEY" \
    --gas-limit 100000 \
    --chain-id "$CHAIN_ID" \
    "$UBTC_CONTRACT_ADDRESS" \
    "transfer(address,uint256)" \
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" \
    "100"

echo "Checking contract state..."
    BALANCE=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "balanceOf(address)" \
        "$ETH_ADDRESS" | cast to-dec)
    TOTAL_SUPPLY=$(cast call --rpc-url "$ETH_RPC_URL" "$UBTC_CONTRACT_ADDRESS" \
        "totalSupply()" | cast to-dec)

    echo "Balance: $BALANCE"
    echo "Total Supply: $TOTAL_SUPPLY"

echo "Done!"