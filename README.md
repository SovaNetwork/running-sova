## running-sova

Orchestrate running Sova validator services in various configurations.

### Sync Git Submodules

```
git submodule sync
git submodule update --init --recursive
```

### Running with Docker

[dockerfiles/dev-docker-compose](./dockerfiles/dev-docker-compose.yml)
- Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.
- When the 'core' profile is specified, sova-reth and sova-sentinel run along side the centralized auxiliary services

```bash
# run single node devnet locally
docker-compose -f dockerfiles/dev-docker-compose.yml -p sova-devnet --profile core up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-docker-compose.yml -p sova-devnet --profile core down -v --rmi all
```

```bash
# run all auxiliary services used by validators
docker-compose -f dockerfiles/dev-docker-compose.yml -p sova-testnet-aux-services up --build -d

# remove all containers and volumes with:
docker-compose -f dockerfiles/dev-docker-compose.yml -p sova-testnet-aux-services down -v --rmi all
```

### Notes

Be sure to create a `.env` file in the dockerfiles folder using the `env.example` file.

Ensure docker is up to date.
