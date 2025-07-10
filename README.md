# running-sova

This is a collection of docker-config files, scripts, and network config artifacts that can be used to orchestrate running a Sova dev node or for the deployment of a fresh chain.

The [config/](/config/) folder contains Sova genesis and rollup JSON files, while the `/dockerfiles` folder contains the docker-compose files used to spin up Sova node services. These services includes the optimsim rollup stack, bitcoin core, and various other sova network services.

The [scripts/](/scripts/) folder servces mainly as a place for network specific testing flows which prove out various aspects of the double-spend protections built into the network. These scripts also serve as a boilerplate to create other scripts which interact with both a bitcoin node to create network "context" and interact with the smart contract deployed on the network itself.

## Running

There are two docker compose file variants, 'dev' and 'testnet'. The primary difference is in 'dev' consensus is mocked at the execution client, where as the 'testnet' implementation use OP rollup consensus.

### dev - [dockerfiles/dev-sova-node](./dockerfiles/dev-sova-node.yml)
- Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.
- When the 'core' profile is specified, sova-reth and sova-sentinel run alongside the Sova auxiliary services.

```bash
# run single node devnet sequencer locally
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core --env-file ./.env up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core --env-file ./.env down -v --rmi all
```

### testnet - [dockerfiles/sova-op-testnet-sequencer-node](./dockerfiles/sova-op-testnet-sequencer-node.yml)
- Used to run a full Sova OP sequencer node.
- Run sova-reth and its supporting services in sequencer mode alongside, op-node, op-batcher and op-proposer. The EL and CL here are configured with specific sequencer applicable flags. For a sequencer node, the EL supporting services consist of an archive BTC node, BTC indexer and db, and a sentinel.

```bash
# run Sova OP sequencer
docker-compose -f dockerfiles/sova-op-testnet-sequencer-node.yml -p sova-op-testnet --profile core --profile op-stack --env-file ./.env up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/sova-op-testnet-sequencer-node.yml -p sova-op-testnet --profile core --profile op-stack --env-file ./.env down -v --rmi all
```

```bash
# only run all auxiliary services used by sequencer
docker-compose -f dockerfiles/sova-op-testnet-sequencer-node.yml -p sova-aux-services --env-file ./.env up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/sova-op-testnet-sequencer-node.yml -p sova-aux-services --env-file ./.env down -v --rmi all
```

### testnet - [dockerfiles/sova-op-testnet-validator-node](./dockerfiles/sova-op-testnet-validator-node.yml)
- Used to run a full Sova OP validator node.
- Run sova-reth and its supporting services in validator mode alongside op-node. The EL and CL here are configured with sequencer specific flags disabled. For a validator node, the EL supporting services consist of only an archive BTC node and a sentinel.

```bash
# run Sova OP validator
docker-compose -f dockerfiles/sova-op-testnet-validator-node.yml -p sova-op-testnet --profile core --profile op-stack --env-file ./.env up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/sova-op-testnet-validator-node.yml -p sova-op-testnet --profile core --profile op-stack --env-file ./.env down -v --rmi all
```

## Chain Config

Refer to the `/config` folder docs for how genesis.json and rollup.json files are created using the [op-deployer](https://docs.optimism.io/operators/chain-operators/tools/op-deployer) chain deployment tool from Optimism. Docker compose files use the files in the `/config` folder directly. If you need to create a new chain deployment follow the steps in the [/config/README.md](/config/README.md). It is important to note that the L2 Genesis creation uses a fork of op-contracts release `tag://op-contracts/v3.0.0-rc.2`. The diff can be found here: [https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...9eec8e4e367ef2b6dac1f8deb9f19ec5006bbd4d](https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...9eec8e4e367ef2b6dac1f8deb9f19ec5006bbd4d).

Services in the docker compose files use a JWT token to safely communicate with eachother. To generate a new JWT token file use: `openssl rand -hex 32 > ~/running-sova/config/<network-name>/jwt.txt`

## Important Details

- Be sure to create a `.env` by copying the `env.example` file.
- Ensure docker is up to date.
- Create a new jwt token `openssl rand -hex 32 > config/<network-name>/jwt.txt`.
- Releases of the op-deployer correlate to specific op-contracts release. Be sure not to mix older op-contracts releases with op-deployer releases or vice versa. This will cause wierd runtime errors. After creating a new genesis.json and rollup.json always record the release versions of the op-deployer you used as well as the forked version of op-contracts that was used. 
- For any new chain deployments always re-run the op-deployer flows and double check the op-deployer intent.json file params and addresses prior to launching the chain. See the "Production setup" section of the [op-deployer docs](https://docs.optimism.io/operators/chain-operators/tools/op-deployer#deployment-usage).
- Anytime a predeploys code changes, new genesis.json and rollup.json files must be created so that the deployed bytecode matches the latest changes to the contracts.
- High level overview of the custom predploy contracts used on Sova OP chain deployments.
    - SovaL1Block.sol - During Sova block building this predeploy captures Bitcoin block execution context. It was designed after Optimism's `L1Block.sol` contract
    - uBTC.sol - native Bitcoin wrapper
        - Need to initialize storage for Ownable.sol.
