#!/bin/bash

set -euo pipefail

# ---------------------
# Chain Config
# ---------------------
L1_CHAIN_ID=11155111
L2_CHAIN_ID=120893
L2_CHAIN_ID_HEX=0x000000000000000000000000000000000000000000000000000000000001d83d
WORKDIR="$HOME/running-sova/config/testnet-sepolia"
OP_DEPLOYER_IMAGE="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2"
ARTIFACTS_URL="https://github.com/SovaNetwork/optimism/releases/download/sova-op-deployer-v0.4.0-rc.2/sova-bedrock-op-testnet-artifacts.tar.gz"

# ---------------------
# Required Environment Variables
# ---------------------
PRIVATE_KEY=${PRIVATE_KEY:-}
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "❌ Error: PRIVATE_KEY environment variable is not set."
  exit 1
fi

L1_RPC_URL=${L1_RPC_URL:-}
if [[ -z "$L1_RPC_URL" ]]; then
  echo "❌ Error: L1_RPC_URL environment variable is not set."
  exit 1
fi

# ---------------------
# Chain Addresses
# ---------------------
# Admin / Common owner
ADMIN_ADDR='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'

# Chain Roles
BATCHER_ADDR='0xaB9A78B755B2550bd570352A1E54ebC15B49cd5B'
CHALLENGER_ADDR='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'
PROPOSER_ADDR='0x9b454B3e1A0b1f4A0eD94264D73a9a72E876e9ea'
UNSAFE_BLOCK_SIGNER='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'

# Superchain Roles
PROTOCOL_OWNER=$ADMIN_ADDR
GUARDIAN_ADDR=$ADMIN_ADDR
PROXY_ADMIN_ADDR=$ADMIN_ADDR

mkdir -p "$WORKDIR"

# ---------------------
# Step 1: Run op-deployer init
# ---------------------
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
# Step 2: Overwrite intent.toml with interop config
# ---------------------
cat > "$WORKDIR/intent.toml" <<EOF
configType = "custom"
l1ChainID = ${L1_CHAIN_ID}
fundDevAccounts = false
useInterop = true
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

echo "✅ intent.toml overwritten with interop config"

# ---------------------
# Step 3: Run op-deployer apply
# ---------------------
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
