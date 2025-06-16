#!/bin/bash

set -euo pipefail

# ---------------------
# Chain Config
# ---------------------
L1_CHAIN_ID=11155111
L2_CHAIN_ID=120893
L2_CHAIN_ID_HEX=0x000000000000000000000000000000000000000000000000000000000001d83d
WORKDIR="$HOME/running-sova/config/testnet"
OP_DEPLOYER_IMAGE="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2"
ARTIFACTS_URL="https://github.com/SovaNetwork/optimism/releases/download/sova-op-deployer-v0.4.0-rc.2/sova-bedrock-op-testnet-artifacts.tar.gz"

# ---------------------
# Chain Addresses
# ---------------------
# Admin
ADMIN_ADDR='0xeE8BF5335b6c795B8922754C2bA88A5C44bAcB16'

# Chain Roles
BATCHER_ADDR='0x4baDc376AA3392e5A63e3ea5d9E1D1E3Ba5C8BcE'
CHALLENGER_ADDR='0xE5353A1c97D2B0e8D6fEc4De622799834024FadB'
PROPOSER_ADDR='0x0d12Ecc37Eb8aF0cE2E9A1C980B2ea548e76c635'
UNSAFE_BLOCK_SIGNER='0x9C63A073306bb0556eD2D5d35ec3f03FCf0bE5eA'

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
  "$OP_DEPLOYER_IMAGE" init \
    --l1-chain-id "$L1_CHAIN_ID" \
    --l2-chain-ids "$L2_CHAIN_ID" \
    --workdir "$WORKDIR" \
    --intent-type custom

echo "✅ op-deployer init complete"

# ---------------------
# Step 2: Overwrite intent.toml with custom configuration
# ---------------------
cat > "$WORKDIR/intent.toml" <<EOF
configType = 'custom'
fundDevAccounts = false
l1ChainID = ${L1_CHAIN_ID}
l1ContractsLocator = '${ARTIFACTS_URL}'
l2ContractsLocator = '${ARTIFACTS_URL}'
useInterop = true

[[chains]]
  baseFeeVaultRecipient = '${ADMIN_ADDR}'
  eip1559Denominator = 50
  eip1559DenominatorCanyon = 250
  eip1559Elasticity = 6
  id = '${L2_CHAIN_ID_HEX}'
  l1FeeVaultRecipient = '${ADMIN_ADDR}'
  operatorFeeConstant = 0
  operatorFeeScalar = 0
  sequencerFeeVaultRecipient = '${ADMIN_ADDR}'

  [[chains.dangerousAdditionalDisputeGames]]
    dangerouslyAllowCustomDisputeParameters = true
    faultGameClockExtension = 10800
    faultGameMaxClockDuration = 302400
    faultGameMaxDepth = 73
    faultGameSplitDepth = 30
    makeRespected = false
    oracleChallengePeriodSeconds = 0
    oracleMinProposalSize = 0
    respectedGameType = 0
    useCustomOracle = false
    vmType = 'CANNON'

  [chains.dangerousAltDAConfig]
    daBondSize = 0
    daChallengeWindow = 100
    daCommitmentType = 'KeccakCommitment'
    daResolveWindow = 100
    useAltDA = false

  [chains.deployOverrides]
    fundDevAccounts = false
    l2BlockTime = 2
    l2GenesisFjordTimeOffset = '0x0'
    l2GenesisGraniteTimeOffset = '0x0'

  [chains.roles]
    batcher = '${BATCHER_ADDR}'
    challenger = '${CHALLENGER_ADDR}'
    l1ProxyAdminOwner = '${ADMIN_ADDR}'
    l2ProxyAdminOwner = '${ADMIN_ADDR}'
    proposer = '${PROPOSER_ADDR}'
    systemConfigOwner = '${ADMIN_ADDR}'
    unsafeBlockSigner = '${UNSAFE_BLOCK_SIGNER}'

[superchainRoles]
  protocolVersionsOwner = '${PROTOCOL_OWNER}'
  superchainGuardian = '${GUARDIAN_ADDR}'
  superchainProxyAdminOwner = '${PROXY_ADMIN_ADDR}'
EOF

echo "✅ intent.toml overwritten with custom values"

# ---------------------
# Step 3: Run op-deployer apply
# ---------------------
docker run --rm -it \
  -v "$WORKDIR":"$WORKDIR" \
  -w "$WORKDIR" \
  "$OP_DEPLOYER_IMAGE" apply \
    --workdir "$WORKDIR"

echo "✅ Chain artifacts generated in: $WORKDIR"
