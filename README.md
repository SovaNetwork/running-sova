## running-sova

Orchestrate running a Sova Validator with user specific chain and BTC configurations.

### Sync Git Submodules

```
git submodule sync
git submodule update --init --recursive
```

### Running with Docker

[dockerfiles/dev-sova-node](./dockerfiles/dev-sova-node.yml)
- Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.
- When the 'core' profile is specified, sova-reth and sova-sentinel run alongside the Sova auxiliary services.

```bash
# run single node devnet locally
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-sova-node.yml -p sova-devnet --profile core down -v --rmi all
```

[dockerfiles/dev-sova-node](./dockerfiles/dev-sova-node.yml)
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

### Notes

- Be sure to create a `.env` file in the dockerfiles folder using the `env.example` file.
- Ensure docker is up to date.
- Create a new jwt token `openssl rand -hex 32 > config/<network-name>/jwt.txt`.
- When creating a new network be sure to copy the genesis.json and rollup.json outputs from running the op-deployer into the `/config` folder.
