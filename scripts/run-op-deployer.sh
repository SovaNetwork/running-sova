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
    
    # Export the generated keys to a file for reference
    cat > "$WORKDIR/generated-keys.env" <<EOF
# OP Rollup Deployment Keys - Generated $(date)
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
export SEQUENCER_PRIVATE_KEY=$SEQUENCER_PRIVATE_KEY
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
WORKDIR="$HOME/running-sova/config/testnet-sepolia-2"
OP_DEPLOYER_IMAGE="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2"
ARTIFACTS_URL="https://github.com/SovaNetwork/optimism/releases/download/sova-op-deployer-v0.4.0-rc.2/sova-bedrock-op-testnet-artifacts.tar.gz"

# ---------------------
# Key Generation or Use Existing
# ---------------------
USE_FRESH_KEYS=${USE_FRESH_KEYS:-false}

if [[ "$USE_FRESH_KEYS" == "true" ]]; then
    mkdir -p "$WORKDIR"
    generate_fresh_keys
    
    # Use generated addresses
    ADMIN_ADDR=$ADMIN_ADDRESS
    BATCHER_ADDR=$BATCHER_ADDRESS
    PROPOSER_ADDR=$PROPOSER_ADDRESS
    CHALLENGER_ADDR=$ADMIN_ADDRESS  # Using admin as challenger
    UNSAFE_BLOCK_SIGNER=$ADMIN_ADDRESS  # Using admin as unsafe block signer
else
    echo "Using existing hardcoded addresses..."
    # Existing hardcoded addresses
    ADMIN_ADDR='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'
    BATCHER_ADDR='0xaB9A78B755B2550bd570352A1E54ebC15B49cd5B'
    CHALLENGER_ADDR='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'
    PROPOSER_ADDR='0x9b454B3e1A0b1f4A0eD94264D73a9a72E876e9ea'
    UNSAFE_BLOCK_SIGNER='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'
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
echo "Role Addresses:"
echo "  Admin: $ADMIN_ADDR"
echo "  Batcher: $BATCHER_ADDR"
echo "  Proposer: $PROPOSER_ADDR"
echo "  Challenger: $CHALLENGER_ADDR"
echo ""

# ---------------------
# Step 1: Run op-deployer init
# ---------------------
echo "Step 1: Initializing op-deployer..."
docker run --rm -it \
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
  SuperchainProxyAdminOwner = "${PROXY_ADMIN_ADDR}"
  SuperchainGuardian = "${GUARDIAN_ADDR}"
  ProtocolVersionsOwner = "${PROTOCOL_OWNER}"

[[chains]]
  id = "${L2_CHAIN_ID_HEX}"
  baseFeeVaultRecipient = "${ADMIN_ADDR}"
  l1FeeVaultRecipient = "${ADMIN_ADDR}"
  sequencerFeeVaultRecipient = "${ADMIN_ADDR}"
  eip1559DenominatorCanyon = 250
  eip1559Denominator = 50
  eip1559Elasticity = 6
  operatorFeeScalar = 0
  operatorFeeConstant = 0

  [chains.roles]
    l1ProxyAdminOwner = "${ADMIN_ADDR}"
    l2ProxyAdminOwner = "${ADMIN_ADDR}"
    systemConfigOwner = "${ADMIN_ADDR}"
    unsafeBlockSigner = "${UNSAFE_BLOCK_SIGNER}"
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
docker run --rm -it \
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
docker run --rm \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" op-deployer inspect genesis \
    --workdir "$WORKDIR" \
    "$L2_CHAIN_ID" > "$WORKDIR/genesis.json"

docker run --rm \
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
if [[ "$USE_FRESH_KEYS" == "true" ]]; then
    echo "  - generated-keys.env: $WORKDIR/generated-keys.env"
    echo ""
    echo "⚠️  IMPORTANT: Save the generated private keys securely!"
fi