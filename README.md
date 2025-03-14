## running-sova

A collection of docker-compose files that orchestrate running Sova validator services in various configurations.

### Sync Git Submodules

```
git submodule sync
git submodule update --init --recursive
```

### Dockerfiles

1. [./dockerfiles/dev-docker-compose](./dockerfiles/dev-docker-compose.yml)
    - Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.

```bash
# run with:
docker-compose -f dockerfiles/dev-docker-compose.yml -p sova-devnet up --build -d

# remove all containers and volumes with:
docker-compose -p sova-devnet down -v --rmi all
```

2. [./dockerfiles/testnet-aux-services-docker-compose](./dockerfiles/testnet-aux-services-docker-compose.yml)
    - Used to run a centralized version of all Sova validator auxiliary services. This bundle of services can be used by a multinode validator testnet cluster.

```bash
# run with:
docker-compose -f dockerfiles/testnet-aux-services-docker-compose.yml -p sova-testnet-aux-services up --build -d

# remove all containers and volumes with:
docker-compose -p sova-testnet-aux-services down -v --rmi all
```

### Notes

Be sure to create a `.env` file in the dockerfiles folder using the `env.example` file.

Ensure docker is up to date.
