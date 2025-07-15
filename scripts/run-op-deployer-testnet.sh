#!/bin/bash

set -euo pipefail

# ---------------------
# Key Generation Function
# ---------------------
generate_fresh_keys() {
    echo "🔑 Generating fresh EVM key pairs for OP rollup deployment..."
    echo "================================================================"
    
    # Check if cast is available
    if ! command -v cast &> /dev/null; then
        echo "❌ Error: cast is not installed. Please install Foundry first (https://foundry.paradigm.xyz)."
        exit 1
    fi
    
    # Function to generate a key pair and extract address
    generate_keypair() {
        local role=$1
        local output=$(cast wallet new 2>/dev/null)
        local address=$(echo "$output" | grep "Address:" | awk '{print $2}')
        local private_key=$(echo "$output" | grep "Private key:" | awk '{print $3}')
        
        eval "${role}_ADDRESS='$address'"
        eval "${role}_PRIVATE_KEY='$private_key'"
        
        echo "$role: $address"
    }
    
    # Generate keys for each role
    generate_keypair "ADMIN"
    generate_keypair "BATCHER" 
    generate_keypair "PROPOSER"
    generate_keypair "SEQUENCER"
    generate_keypair "CHALLENGER"
    generate_keypair "L2_PROXY_ADMIN_OWNER"
    generate_keypair "SYSTEM_CONFIG_OWNER"
    generate_keypair "UNSAFE_BLOCK_SIGNER"
    generate_keypair "BASE_FEE_VAULT_RECIPIENT"
    generate_keypair "L1_FEE_VAULT_RECIPIENT"
    generate_keypair "SEQUENCER_FEE_VAULT_RECIPIENT"
    
    # Export the generated keys to a file for reference
    cat > "$WORKDIR/generated-keys.env" <<EOF
# OP Rollup Deployment Keys - Generated $(date)
# WARNING: These are fresh private keys. Keep them secure!

# Admin account (used for superchain roles and l1ProxyAdminOwner)
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
export SEQUENCER_PRIVATE_KEY=$SEQUENCER_PRIVATE_KEY

# Challenger account
export CHALLENGER_ADDRESS=$CHALLENGER_ADDRESS
export CHALLENGER_PRIVATE_KEY=$CHALLENGER_PRIVATE_KEY

# L2 Proxy Admin Owner account
export L2_PROXY_ADMIN_OWNER_ADDRESS=$L2_PROXY_ADMIN_OWNER_ADDRESS
export L2_PROXY_ADMIN_OWNER_PRIVATE_KEY=$L2_PROXY_ADMIN_OWNER_PRIVATE_KEY

# System Config Owner account
export SYSTEM_CONFIG_OWNER_ADDRESS=$SYSTEM_CONFIG_OWNER_ADDRESS
export SYSTEM_CONFIG_OWNER_PRIVATE_KEY=$SYSTEM_CONFIG_OWNER_PRIVATE_KEY

# Unsafe Block Signer account
export UNSAFE_BLOCK_SIGNER_ADDRESS=$UNSAFE_BLOCK_SIGNER_ADDRESS
export UNSAFE_BLOCK_SIGNER_PRIVATE_KEY=$UNSAFE_BLOCK_SIGNER_PRIVATE_KEY

# Base Fee Vault Recipient account
export BASE_FEE_VAULT_RECIPIENT_ADDRESS=$BASE_FEE_VAULT_RECIPIENT_ADDRESS
export BASE_FEE_VAULT_RECIPIENT_PRIVATE_KEY=$BASE_FEE_VAULT_RECIPIENT_PRIVATE_KEY

# L1 Fee Vault Recipient account
export L1_FEE_VAULT_RECIPIENT_ADDRESS=$L1_FEE_VAULT_RECIPIENT_ADDRESS
export L1_FEE_VAULT_RECIPIENT_PRIVATE_KEY=$L1_FEE_VAULT_RECIPIENT_PRIVATE_KEY

# Sequencer Fee Vault Recipient account
export SEQUENCER_FEE_VAULT_RECIPIENT_ADDRESS=$SEQUENCER_FEE_VAULT_RECIPIENT_ADDRESS
export SEQUENCER_FEE_VAULT_RECIPIENT_PRIVATE_KEY=$SEQUENCER_FEE_VAULT_RECIPIENT_PRIVATE_KEY
EOF
    
    echo "🔐 Keys saved to: $WORKDIR/generated-keys.env"
    echo ""
}

# ---------------------
# Chain Config
# ---------------------
L1_CHAIN_ID=11155111
L2_CHAIN_ID=120893
L2_CHAIN_ID_HEX=0x000000000000000000000000000000000000000000000000000000000001d83d
WORKDIR="$HOME/running-sova/config/testnet-sepolia"
OP_DEPLOYER_IMAGE="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.3.3"
ARTIFACTS_URL="https://github.com/SovaNetwork/optimism/releases/download/op-deployer-v0.3.3-op-contracts-v3.0.0-892d01c/sova-bedrock-op-testnet-artifacts.tar.gz"

# ---------------------
# Key Management - Check for existing keys or generate fresh ones
# ---------------------
FORCE_REGENERATE=${FORCE_REGENERATE:-false}
mkdir -p "$WORKDIR"
KEYS_FILE="$WORKDIR/generated-keys.env"

if [[ -f "$KEYS_FILE" && "$FORCE_REGENERATE" != "true" ]]; then
    echo "📋 Found existing keys file: $KEYS_FILE"
    echo "Loading existing generated addresses..."

    # Source the existing keys file to load the addresses
    # shellcheck source=$HOME/running-sova/config/testnet-sepolia/generated-keys.env
    source "$KEYS_FILE"

    # Use loaded addresses
    ADMIN_ADDR=$ADMIN_ADDRESS
    BATCHER_ADDR=$BATCHER_ADDRESS
    PROPOSER_ADDR=$PROPOSER_ADDRESS
    CHALLENGER_ADDR=$CHALLENGER_ADDRESS
    L2_PROXY_ADMIN_OWNER_ADDR=$L2_PROXY_ADMIN_OWNER_ADDRESS
    SYSTEM_CONFIG_OWNER_ADDR=$SYSTEM_CONFIG_OWNER_ADDRESS
    UNSAFE_BLOCK_SIGNER_ADDR=$UNSAFE_BLOCK_SIGNER_ADDRESS
    BASE_FEE_VAULT_RECIPIENT_ADDR=$BASE_FEE_VAULT_RECIPIENT_ADDRESS
    L1_FEE_VAULT_RECIPIENT_ADDR=$L1_FEE_VAULT_RECIPIENT_ADDRESS
    SEQUENCER_FEE_VAULT_RECIPIENT_ADDR=$SEQUENCER_FEE_VAULT_RECIPIENT_ADDRESS

    echo "✅ Using existing generated addresses"
else
    if [[ "$FORCE_REGENERATE" == "true" ]]; then
        echo "FORCE_REGENERATE=true - Generating new keys even though file exists..."
    else
        echo "No existing keys file found - Generating fresh keys..."
    fi

    generate_fresh_keys

    # Use generated addresses
    ADMIN_ADDR=$ADMIN_ADDRESS
    BATCHER_ADDR=$BATCHER_ADDRESS
    PROPOSER_ADDR=$PROPOSER_ADDRESS
    CHALLENGER_ADDR=$CHALLENGER_ADDRESS
    L2_PROXY_ADMIN_OWNER_ADDR=$L2_PROXY_ADMIN_OWNER_ADDRESS
    SYSTEM_CONFIG_OWNER_ADDR=$SYSTEM_CONFIG_OWNER_ADDRESS
    UNSAFE_BLOCK_SIGNER_ADDR=$UNSAFE_BLOCK_SIGNER_ADDRESS
    BASE_FEE_VAULT_RECIPIENT_ADDR=$BASE_FEE_VAULT_RECIPIENT_ADDRESS
    L1_FEE_VAULT_RECIPIENT_ADDR=$L1_FEE_VAULT_RECIPIENT_ADDRESS
    SEQUENCER_FEE_VAULT_RECIPIENT_ADDR=$SEQUENCER_FEE_VAULT_RECIPIENT_ADDRESS
fi

# Superchain Roles
PROTOCOL_OWNER=$ADMIN_ADDR
GUARDIAN_ADDR=$ADMIN_ADDR
PROXY_ADMIN_ADDR=$ADMIN_ADDR

# ---------------------
# Required Environment Variables
# ---------------------
PRIVATE_KEY=${PRIVATE_KEY:-}
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "❌ Error: PRIVATE_KEY environment variable is not set."
  echo "This should be the private key for funding/deploying (not one of the generated role keys)"
  exit 1
fi

L1_RPC_URL=${L1_RPC_URL:-}
if [[ -z "$L1_RPC_URL" ]]; then
  echo "❌ Error: L1_RPC_URL environment variable is not set."
  exit 1
fi

mkdir -p "$WORKDIR"

# ---------------------
# Display Configuration
# ---------------------
echo "🚀 OP Stack Deployment Configuration"
echo "===================================="
echo "L1 Chain ID: $L1_CHAIN_ID"
echo "L2 Chain ID: $L2_CHAIN_ID"
echo "Work Directory: $WORKDIR"
echo ""
echo "Superchain Admin Roles (using ADMIN_ADDR):"
echo "  SuperchainProxyAdminOwner: $ADMIN_ADDR"
echo "  SuperchainGuardian: $ADMIN_ADDR"
echo "  ProtocolVersionsOwner: $ADMIN_ADDR"
echo "  L1ProxyAdminOwner: $ADMIN_ADDR"
echo ""
echo "Unique Role Addresses:"
echo "  Batcher: $BATCHER_ADDR"
echo "  Proposer: $PROPOSER_ADDR"
echo "  Challenger: $CHALLENGER_ADDR"
echo "  L2ProxyAdminOwner: $L2_PROXY_ADMIN_OWNER_ADDR"
echo "  SystemConfigOwner: $SYSTEM_CONFIG_OWNER_ADDR"
echo "  UnsafeBlockSigner: $UNSAFE_BLOCK_SIGNER_ADDR"
echo "  BaseFeeVaultRecipient: $BASE_FEE_VAULT_RECIPIENT_ADDR"
echo "  L1FeeVaultRecipient: $L1_FEE_VAULT_RECIPIENT_ADDR"
echo "  SequencerFeeVaultRecipient: $SEQUENCER_FEE_VAULT_RECIPIENT_ADDR"
echo ""

# ---------------------
# Step 1: Run op-deployer init
# ---------------------
echo "Step 1: Initializing op-deployer..."
docker run --rm -it --platform linux/amd64 \
  --entrypoint="" \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" op-deployer init \
    --l1-chain-id "$L1_CHAIN_ID" \
    --l2-chain-ids "$L2_CHAIN_ID" \
    --workdir "$WORKDIR" \
    --intent-type custom

echo "✅ op-deployer init complete"

# ---------------------
# Step 2: Overwrite intent.toml
# ---------------------
echo "Step 2: Creating intent.toml..."
cat > "$WORKDIR/intent.toml" <<EOF
configType = "custom"
l1ChainID = ${L1_CHAIN_ID}
fundDevAccounts = false
useInterop = false
l1ContractsLocator = "${ARTIFACTS_URL}"
l2ContractsLocator = "${ARTIFACTS_URL}"

[superchainRoles]
  ProxyAdminOwner = "${PROXY_ADMIN_ADDR}"
  ProtocolVersionsOwner = "${PROTOCOL_OWNER}"
  Guardian = "${GUARDIAN_ADDR}"

[[chains]]
  id = "${L2_CHAIN_ID_HEX}"
  baseFeeVaultRecipient = "${BASE_FEE_VAULT_RECIPIENT_ADDR}"
  l1FeeVaultRecipient = "${L1_FEE_VAULT_RECIPIENT_ADDR}"
  sequencerFeeVaultRecipient = "${SEQUENCER_FEE_VAULT_RECIPIENT_ADDR}"
  eip1559DenominatorCanyon = 250
  eip1559Denominator = 50
  eip1559Elasticity = 6
  operatorFeeScalar = 0
  operatorFeeConstant = 0

  [chains.roles]
    l1ProxyAdminOwner = "${ADMIN_ADDR}"
    l2ProxyAdminOwner = "${L2_PROXY_ADMIN_OWNER_ADDR}"
    systemConfigOwner = "${SYSTEM_CONFIG_OWNER_ADDR}"
    unsafeBlockSigner = "${UNSAFE_BLOCK_SIGNER_ADDR}"
    batcher = "${BATCHER_ADDR}"
    proposer = "${PROPOSER_ADDR}"
    challenger = "${CHALLENGER_ADDR}"

  [chains.deployOverrides]
    l2BlockTime = 2

[globalDeployOverrides]
  l2GenesisInteropTimeOffset = "0x0"
  l2GenesisIsthmusTimeOffset = "0x0"
EOF

echo "✅ intent.toml created"

# ---------------------
# Step 3: Run op-deployer apply
# ---------------------
echo "Step 3: Deploying contracts..."
docker run --rm -it --platform linux/amd64 \
  --entrypoint="" \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" op-deployer apply \
    --workdir "$WORKDIR" \
    --l1-rpc-url "$L1_RPC_URL" \
    --private-key "$PRIVATE_KEY"

echo "✅ Chain artifacts generated in: $WORKDIR"

# ---------------------
# Step 4: Extract genesis.json and rollup.json
# ---------------------
echo "Step 4: Extracting configuration files..."
docker run --rm --platform linux/amd64 \
  --entrypoint="" \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" op-deployer inspect genesis \
    --workdir "$WORKDIR" \
    "$L2_CHAIN_ID" > "$WORKDIR/genesis.json"

docker run --rm --platform linux/amd64 \
  --entrypoint="" \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" op-deployer inspect rollup \
    --workdir "$WORKDIR" \
    "$L2_CHAIN_ID" > "$WORKDIR/rollup.json"

echo "✅ Exported genesis.json and rollup.json to: $WORKDIR"

# ---------------------
# Summary
# ---------------------
echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo "Configuration files:"
echo "  - genesis.json: $WORKDIR/genesis.json"
echo "  - rollup.json: $WORKDIR/rollup.json"
echo "  - generated-keys.env: $WORKDIR/generated-keys.env"
echo ""
echo "⚠️  IMPORTANT: Save the generated private keys securely!"
echo ""
echo "Address Summary:"
echo "  Admin roles use: $ADMIN_ADDR"
echo "  All other roles have unique addresses (see generated-keys.env)"
echo ""
echo "💡 Tip: To force regenerate keys even if file exists, use: FORCE_REGENERATE=true" the default behavior