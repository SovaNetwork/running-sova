# A Guide to Bootstrapping the Hyperstate Network

This is a comprehensive guide to launching Hyperstate, a proof-of-stake (PoS) EVM network, without going through a 'merge' ceremony. Meaning all PoS functionality will be available at the genesis block. The three main service which make up a PoS network are the execution client, beacon node, and validator client.

- Execution Client: A service which enforces the rules of the ethereum virtual machine (EVM).
    - [Hyperstate Reth](https://github.com/OnCorsa/corsa-reth)
- Beacon Node:  The primary component which connects to the PoS network, it is responsible for managing peer connections and block propagation.
    - [Lighthouse](https://github.com/sigp/lighthouse)
- Validation Client: When connected to a beacon node, performs the duties of a staked validator (e.g., proposing blocks and attestations).
    - [Lighthouse](https://github.com/sigp/lighthouse)

## Process Overview
1. [Configuration](#configuration)
    - [genesis.json](#genesisjson)
    - [config.yaml](#configyaml)
    - [genesis.ssz](#genesisssz)
2. [Start Execution Clients](#start-execution-clients)
3. [Start Beacon Nodes](#start-beacon-nodes)
4. [Generate Validator Keys](#generate-validator-keys)
5. [Start Validator Client](#start-validator-client)

## Process

### Configuration

#### genesis.json

The genesis.json file is used by the execution client to define the genesis block for the network. Since blockchains are a sequence of blocks, the chain must start somewhere.

[genesis.json](https://github.com/OnCorsa/corsa-reth/blob/main/genesis.json)

Genesis Notes:
- Predeployed staking deposit contract at `0x4242424242424242424242424242424242424242`.
- Whale wallet with entire initial supply of network tokens.
- Time stamp to be adjusted to just before the services here are started.
- Difficulty is as low as possible since we are using PoS not PoW.
- `mergeForkBlock` and `mergeNetsplitBlock` set to zero indicating at genesis PoS is active.

#### config.yaml

The config.yaml file is used by the beacon node and the validator client for defining the network configuration.

[config.yaml](/consensus-config/hyperstate/config.yaml): `./consensus-config/hyperstate/config.yaml`

Notes:
- `TERMINAL_TOTAL_DIFFICULTY` is set to zero.
- `TERMINAL_BLOCK_HASH` ***This must be set to the block hash of the genesis block.*** This hash can be pulled from the execution client once it has been started using: `cast block 0 --rpc-url http://localhost:8545`.
- `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` is set to 1 for initial bootstrapping. This value determines the minimum number of active validators required for the genesis state.
- All fork upgrades set to active at genesis and they have versions which do not conflict with other public networks.

#### genesis.ssz

The SSZ-encoded genesis state for the beacon chain. This encoding contains the initial validator set, the genesis time, fork version, genesis validators root, and other state roots.

This file for Hyperstate was generated using [eth2-testnet-genesis](https://github.com/protolambda/eth2-testnet-genesis). This utility is used for generating an Eth2 genesis state, eliminating the need to make deposits for all validators. When using this tool, it is important to use the validator mnemonic that you generate in [Generate Validator Keys](#generate-validator-keys) section. This will also prompt you for the number of validators you wish that key to be associated with

[genesis.ssz](/consensus-config/hyperstate/genesis.ssz): `./consensus-config/hyperstate/genesis.ssz`

This file was generated with the following:
```bash
cd eth2-testnet-genesis

make install

make build

# Be sure to generate a mnemonics.yaml file prior to running this command. https://github.com/protolambda/eth2-testnet-genesis?tab=readme-ov-file#mnemonics
eth2-testnet-genesis deneb --config=~/running-corsa/consensus-config/hyperstate/config.yaml --eth1-config=~/corsa-reth/genesis.json --mnemonics=mnemonics.yaml --shadow-fork-eth1-rpc=http://localhost:8545
```

### Start Execution Clients

> A minimum of two execution clients must be operating to consist of a 'network'.

***NOTE: This guide does not outline how to setup the execution client auxiliary services (BTC node, signing service, UTXO services...) please refer to the [docker-compose](/docker-compose.yml) file for setting up those services.***

1. Navigate to the execution client repository and build its contents
```bash
cd corsa-reth

cargo build --release
```

2. Start the first client
```bash
./target/release/corsa-reth node \
    --chain genesis.json \
    --btc-network "regtest" \
    --network-url "http://127.0.0.1" \
    --btc-rpc-username "user" \
    --btc-rpc-password "password" \
    --network-signing-url "http://127.0.0.1:5555" \
    --network-utxo-url "http://127.0.0.1:5557" \
    --btc-tx-queue-url "http://127.0.0.1:5558" \
    --addr "0.0.0.0" \
    --port 30303 \
    --discovery.addr "0.0.0.0" \
    --discovery.port 30303 \
    --http \
    --http.addr "127.0.0.1" \
    --http.port 8545 \
    --ws \
    --ws.addr "127.0.0.1" \
    --ws.port 8546 \
    --http.api all \
    --authrpc.addr "127.0.0.1" \
    --authrpc.port 8551 \
    --datadir ./data \
    --log.stdout.filter info
```

3. In another terminal start the second execution client
```bash
./target/release/corsa-reth node \
    --chain genesis.json \
    --btc-network "regtest" \
    --network-url "http://127.0.0.1" \
    --btc-rpc-username "user" \
    --btc-rpc-password "password" \
    --network-signing-url "http://127.0.0.1:5555" \
    --network-utxo-url "http://127.0.0.1:5557" \
    --btc-tx-queue-url "http://127.0.0.1:5558" \
    --addr "0.0.0.0" \
    --port 30304 \
    --discovery.addr "0.0.0.0" \
    --discovery.port 30304 \
    --http \
    --http.addr "127.0.0.1" \
    --http.port 8547 \
    --ws \
    --ws.addr "127.0.0.1" \
    --ws.port 8548 \
    --http.api all \
    --authrpc.addr "127.0.0.1" \
    --authrpc.port 8552 \
    --datadir ./data-2 \
    --log.stdout.filter info
```
Notice for the second client, a new data directory is used as well as different port numbers. This is to ensure there are no colliding ports if starting the two clients on the same machine.

### Start Beacon Nodes

1. Make sure you have lighthouse installed:
```bash
brew install lighthouse

# verify installation
lighthouse -h
```

2. Start the first beacon node, which will use to the first execution client we started.
```bash
lighthouse bn \
    --testnet-dir ~/running-corsa/consensus-config/hyperstate \
    --execution-endpoint http://localhost:8551 \
    --execution-jwt ~/corsa-reth/data/jwt.hex \
    --allow-insecure-genesis-sync \
    --datadir ./data \
    --http \
    --http-port 5052 \
    --port 9000 \
    --port6 9090 \
    --debug-level info 
```

3. Start the second beacon node, which will use the second execution client we started
```bash
lighthouse bn \
    --testnet-dir ~/running-corsa/consensus-config/hyperstate \
    --execution-endpoint http://localhost:8552 \
    --execution-jwt ~/corsa-reth/data-2/jwt.hex \
    --allow-insecure-genesis-sync \
    --datadir ./data-2 \
    --http \
    --http-port 5053 \
    --port 9002 \
    --port6 9091 \
    --debug-level info
```
Notice for the second node, it uses the execution endpoint for the second execution client we started. It also has its own data directory and different port numbers from the first beacon node.

### Generate Validator Keys

> To generate validator keys, Lighthouse recommends using the [ethereum/staking-deposit-cli](https://github.com/ethereum/staking-deposit-cli)

***NOTE: In a production setting it is extremely important to keep your validator keys safe and proactively exercise safe key management practices to keep your mnemonic safe.***

1. To build the staking-deposit-cli I found the easiest way is to use Docker:
```bash
cd staking-deposit-cli
make build_docker
```

2. Generate validator keys
```bash
docker run -it --rm \
    -v $(pwd)/validator_keys:/app/validator_keys \
    ethereum/staking-deposit-cli \
    new-mnemonic \
    --num_validators 1 \
    --chain mainnet \
    --eth1_withdrawal_address 0x1a0Fe90f5Bf076533b2B74a21b3AaDf225CdDfF7
```
Go through the prompts and at the end you will receive a generated mnemonic for your validator keys.

3. To view your pubkey and deposit data use:
```bash
cat validator_keys/deposit_data-*.json
cat validator_keys/keystore-m_12381_3600_0_0_0-1732048816.json
```

### Start Validator Client

1. Import validator keys
```bash
lighthouse account validator import \
    --testnet-dir ~/running-corsa/consensus-config/hyperstate \
    --directory ~/staking-deposit-cli/validator_keys 
```

2. View imported keys for Hyperstate
```bash
lighthouse account validator list \
    --testnet-dir ~/running-corsa/consensus-config/hyperstate
```

3. Start the validator client
```bash
lighthouse vc \
    --testnet-dir ~/running-corsa/consensus-config/hyperstate \
    --suggested-fee-recipient 0x5f7Bd2e3145c45fAa5F492a78112D548174Cc944
```

## References
- [How to merge an Ethereum network right from the genesis block](https://dev.to/q9/how-to-merge-an-ethereum-network-right-from-the-genesis-block-3454)

- [protolambda/merge-genesis-tools](https://github.com/protolambda/merge-genesis-tools)

- [Prysm Docs - How to Set Up an Ethereum Proof-of-Stake Devnet in Minutes](https://docs.prylabs.network/docs/advanced/proof-of-stake-devnet)

- [ethpandaops/ethereum-genesis-generator](https://github.com/ethpandaops/ethereum-genesis-generator)

- [ethereum/consensus-specs](https://github.com/ethereum/consensus-specs)

- [Reth Docs](https://reth.rs/run/run-a-node.html)

- [Lighthouse Docs](https://lighthouse-book.sigmaprime.io/run_a_node.html)

- [Conversion in Lighthouse Discord](https://discord.com/channels/605577013327167508/710978433823277099/1171437024776044584)
    - Search "whats the testnet-dir in the lighthouse beacon parameters" in 'newbie' channel. Follow yaxir's conversation about setting up a custom network it is long and informative.