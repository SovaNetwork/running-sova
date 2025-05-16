# running-sova

This is a collection of docker and config files used to orchestrate running a Sova dev node or standing up a fresh Sova network.

The `config/` folder contains Sova genesis and rollup JSON files, while the `/dockerfiles` folder contains the docker-compose files used to spin up Sova nodes.

## Installation

```bash
# Sync Git Submodules

git submodule sync
git submodule update --init --recursive
```

## Running

### [dockerfiles/dev-sova-node](./dockerfiles/dev-sova-node.yml)
- Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.
- When the 'core' profile is specified, sova-reth and sova-sentinel run alongside the Sova auxiliary services.

```bash
# run single node devnet locally
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core down -v --rmi all
```

### [dockerfiles/dev-sova-op-sequencer-node](./dockerfiles/dev-sova-op-sequencer-node.yml)
- Used to run a full Sova OP Sequencer node.
- When the 'core' and 'op-stack' profiles are specified sova-reth, sova-sentinel, op-node, op-batcher, op-proposer all run alongside the Sova auxiliary services.

```bash
# run all auxiliary services used by validators
docker-compose -f dockerfiles/dev-sova-op-sequencer-node.yml -p sova-op-testnet --profile core --profile op-stack up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-sova-op-sequencer-node.yml -p sova-op-testnet --profile core --profile op-stack down -v --rmi all
```

```bash
# run all auxiliary services used by validators
docker-compose -f dockerfiles/dev-sova-op-sequencer-node.yml -p sova-aux-services up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-sova-op-sequencer-node.yml -p sova-aux-services down -v --rmi all
```

## Chain Config

Refer to the `/config` folder docs for how genesis.json and rollup.json files are created using the [op-deployer](https://docs.optimism.io/operators/chain-operators/tools/op-deployer) chain deployment tool from Optimism. Docker compose files use the files in the `/config` folder directly. If you need to create a new chain deployment follow the steps in the [/config/README.md](/config/README.md). It is important to note that the L2 Genesis creation uses a fork of op-contracts release `tag://op-contracts/v3.0.0-rc.2`. The diff can be found here: [https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...9eec8e4e367ef2b6dac1f8deb9f19ec5006bbd4d](https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...9eec8e4e367ef2b6dac1f8deb9f19ec5006bbd4d).

Services in the docker compose files use a JWT token to safely communicate with eachother. To generate a new JWT token file use: `openssl rand -hex 32 > ~/running-sova/config/<network-name>/jwt.txt`

## Important Details

- Be sure to create a `.env` file in the dockerfiles folder using the `env.example` file.
- Ensure docker is up to date.
- Create a new jwt token `openssl rand -hex 32 > config/<network-name>/jwt.txt`.
- Releases of the op-deployer correlate to specific op-contracts release. Be sure not to mix older op-contracts releases with op-deployer releases or vice versa. This will cause wierd runtime errors. After creating a new genesis.json and rollup.json always record the release versions of the op-deployer you used as well as the forked version of op-contracts that was used. 
- For any new chain deployments always re-run the op-deployer flows and double check the op-deployer intent.json file params and addresses prior to launching the chain. See the "Production setup" section of the [op-deployer docs](https://docs.optimism.io/operators/chain-operators/tools/op-deployer#deployment-usage).
- Anytime a predeploys code changes, new genesis.json and rollup.json files must be created so that the deployed bytecode matches the latest changes to the contracts.
- High level overview of the custom predploy contracts used on Sova OP chain deployments.
    - SovaL1Block.sol - During Sova block building this predeploy captures Bitcoin block execution context. It was designed after Optimism's `L1Block.sol` contract
    - uBTC.sol - native Bitcoin wrapper
        - Need to initialize storage for Ownable.sol.
