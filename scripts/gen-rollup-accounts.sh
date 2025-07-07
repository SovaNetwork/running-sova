#!/bin/bash

# Script to generate fresh EVM key pairs for OP rollup deployment
# This will create 4 accounts by running `cast wallet new` for each role.

set -e

echo "🔑 Generating fresh EVM key pairs for OP rollup deployment..."
echo "================================================================"

# Function to generate a key pair and extract address and private key
generate_keypair() {
    local role=$1
    
    # Generate new keypair with cast
    local output=$(cast wallet new 2>/dev/null)
    
    # Extract address and private key from the output
    # cast wallet new outputs in format:
    # Successfully created new keypair.
    # Address: 0x...
    # Private key: 0x...
    local address=$(echo "$output" | grep "Address:" | awk '{print $2}')
    local private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
    
    # Store in global variables using eval
    eval "${role}_ADDRESS='$address'"
    eval "${role}_PRIVATE_KEY='$private_key'"
}

# Check if required tools are installed
if ! command -v cast &> /dev/null; then
    echo "❌ Error: cast is not installed. Please install Foundry first."
    echo "Run: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# Generate key pairs for each role
generate_keypair "ADMIN"
generate_keypair "BATCHER" 
generate_keypair "PROPOSER"
generate_keypair "SEQUENCER"

# Create .env content
ENV_CONTENT="# OP Rollup Deployment Keys - Generated $(date)
# WARNING: These are fresh private keys. Keep them secure!

# Admin account
export ADMIN_ADDRESS=$ADMIN_ADDRESS
export ADMIN_PRIVATE_KEY=$ADMIN_PRIVATE_KEY

# Batcher account  
export BATCHER_ADDRESS=$BATCHER_ADDRESS
export BATCHER_PRIVATE_KEY=$BATCHER_PRIVATE_KEY

# Proposer account
export PROPOSER_ADDRESS=$PROPOSER_ADDRESS
export PROPOSER_PRIVATE_KEY=$PROPOSER_PRIVATE_KEY

# Sequencer account
export SEQUENCER_ADDRESS=$SEQUENCER_ADDRESS
export SEQUENCER_PRIVATE_KEY=$SEQUENCER_PRIVATE_KEY"

# Output to both console and file
echo "$ENV_CONTENT"
echo ""